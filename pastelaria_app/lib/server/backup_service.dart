import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import 'package:path/path.dart' as p;
import 'order_store.dart';

class BackupService {
  static const tables = [
    'products',
    'orders',
    'meta',
    'commands',
    'print_jobs'
  ];
  static String newKey() => base64UrlEncode(
      List<int>.generate(32, (_) => Random.secure().nextInt(256)));
  static SecretKey _key(String recoveryKey) {
    final bytes = base64Url.decode(recoveryKey.trim());
    if (bytes.length != 32) {
      throw const FormatException('Chave de recuperação inválida.');
    }
    return SecretKey(bytes);
  }

  static Future<List<int>> encode(
      Map<String, dynamic> snapshot, String key) async {
    final box = await AesGcm.with256bits().encrypt(
        gzip.encode(utf8.encode(jsonEncode(snapshot))),
        secretKey: _key(key));
    return utf8.encode(jsonEncode({
      'format': 'pastelaria-backup-v1',
      'nonce': base64Encode(box.nonce),
      'mac': base64Encode(box.mac.bytes),
      'ciphertext': base64Encode(box.cipherText)
    }));
  }

  static Future<Map<String, dynamic>> decode(
      List<int> bytes, String key) async {
    final envelope = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    if (envelope['format'] != 'pastelaria-backup-v1') {
      throw const FormatException('Formato de backup desconhecido.');
    }
    final clear = await AesGcm.with256bits().decrypt(
        SecretBox(base64Decode(envelope['ciphertext'] as String),
            nonce: base64Decode(envelope['nonce'] as String),
            mac: Mac(base64Decode(envelope['mac'] as String))),
        secretKey: _key(key));
    final result =
        jsonDecode(utf8.decode(gzip.decode(clear))) as Map<String, dynamic>;
    if (result['schema'] != 1 || result['tables'] is! Map) {
      throw const FormatException('Schema de backup incompatível.');
    }
    return result;
  }

  static Future<File> create(
      OrderStore store, Directory directory, String key) async {
    final snapshot = await store.db.transaction((tx) async {
      final contents = <String, dynamic>{};
      for (final table in tables) {
        contents[table] = await tx.query(table);
      }
      return {
        'schema': 1,
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'tables': contents
      };
    });
    final bytes = await encode(snapshot, key);
    // Authenticate the snapshot before publishing it as a completed backup.
    await decode(bytes, key);
    await directory.create(recursive: true);
    final name =
        'pastelaria-${store.day}-${DateTime.now().toUtc().toIso8601String().replaceAll(':', '-')}.pastelbackup';
    final temporary = File(p.join(directory.path, '$name.tmp'));
    await temporary.writeAsBytes(bytes, flush: true);
    final completed = await temporary.rename(p.join(directory.path, name));
    final old = directory
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.pastelbackup'))
        .toList()
      ..sort((a, b) => b.path.compareTo(a.path));
    final retainedDays = <String>{};
    for (final file in old) {
      final day = p.basename(file.path).substring(11, 21);
      if (retainedDays.contains(day) || retainedDays.length >= 7) {
        await file.delete();
      } else {
        retainedDays.add(day);
      }
    }
    return completed;
  }

  /// Restore only into an empty target. Never replace a running shop database.
  static Future<void> restoreEmpty(
      OrderStore target, List<int> bytes, String key) async {
    final snapshot = await decode(bytes, key);
    final data = snapshot['tables'] as Map;
    for (final table in tables) {
      if (data[table] is! List) throw FormatException('Tabela ausente: $table');
    }
    for (final raw in data['orders'] as List) {
      final order = jsonDecode((raw as Map)['data'] as String) as Map;
      if (order['id'] != raw['id'] ||
          !['aberto', 'fechado', 'cancelado'].contains(order['status']) ||
          raw['status'] != order['status']) {
        throw const FormatException('Pedido inválido no backup.');
      }
      for (final item in order['itens'] as List) {
        final quantity = item['quantidade'] as int;
        final ready = item['quantidade_pronta'] as int;
        final delivered = item['quantidade_entregue'] as int;
        final cancelled = item['quantidade_cancelada'] as int;
        if (quantity <= 0 ||
            cancelled < 0 ||
            delivered < 0 ||
            delivered > ready ||
            ready > quantity - cancelled) {
          throw const FormatException('Saldos inválidos no backup.');
        }
      }
    }
    await target.db.transaction((tx) async {
      if ((await tx.query('orders', limit: 1)).isNotEmpty) {
        throw BusinessError(
            'Restauração permitida apenas em um servidor sem pedidos.');
      }
      for (final table in tables.reversed) {
        await tx.delete(table);
      }
      for (final table in tables) {
        for (final raw in data[table] as List) {
          final row = Map<String, Object?>.from(raw as Map);
          if (table == 'print_jobs' &&
              ['pendente', 'enviando'].contains(row['status'])) {
            row['status'] = 'incerto';
            row['error'] =
                'Backup restaurado. Confira antes de solicitar segunda via.';
          }
          await tx.insert(table, row);
        }
      }
      final violations = await tx.rawQuery('PRAGMA foreign_key_check');
      if (violations.isNotEmpty) {
        throw const FormatException('Referências inválidas no backup.');
      }
    });
  }
}
