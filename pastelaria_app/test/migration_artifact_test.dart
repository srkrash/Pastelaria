import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:pastelaria_app/server/backup_service.dart';
import 'package:pastelaria_app/server/order_store.dart';

// Opt-in local conversion verification. No production data belongs in fixtures
// or the APK. MIGRATION_DIR must point to the Git-ignored private export.
void main() {
  final directory = Platform.environment['MIGRATION_DIR'];
  test('legacy conversion restores through the actual tablet backup service',
      () async {
    final folder = Directory(directory!);
    final reportFile = File('${folder.path}/report.json');
    final report = jsonDecode(await reportFile.readAsString()) as Map;
    tz.initializeTimeZones();
    sqfliteFfiInit();
    final source = await databaseFactoryFfi.openDatabase(
        '${folder.path}/pastelaria_v2.db',
        options: OpenDatabaseOptions(readOnly: true));
    final target = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath,
        options: OpenDatabaseOptions(
            version: 1,
            onConfigure: (db) => db.execute('PRAGMA foreign_keys=ON'),
            onCreate: OrderStore.createSchema));
    try {
      final sourceStore = OrderStore(source);
      final targetStore = OrderStore(target);
      final key = BackupService.newKey();
      final backup = await BackupService.create(sourceStore, folder, key);
      final bytes = await backup.readAsBytes();
      await BackupService.restoreEmpty(targetStore, bytes, key);
      final snapshot = await targetStore.snapshot();
      final orders = snapshot['pedidos'] as List;
      expect(orders.length, report['orders']);
      expect((await targetStore.products()).length, report['products']);
      expect((await targetStore.snapshot(activeOnly: true))['pedidos'], isEmpty);
      expect(await target.query('print_jobs'), isEmpty);
      var total = 0;
      var items = 0;
      for (final order in orders) {
        total += order['total_centavos'] as int;
        expect(order['legacy'], isNotNull);
        for (final item in order['itens'] as List) {
          items++;
          expect(item['quantidade_pronta'],
              item['quantidade'] - item['quantidade_cancelada']);
          expect(item['quantidade_entregue'], item['quantidade_pronta']);
        }
      }
      expect(total, report['total_centavos']);
      expect(items, report['items']);
      final products = await targetStore.products('bebida');
      final newOrder = await targetStore.command('migration-rehearsal', 'create', {
        'itens': [
          {'produto_nome': products.first['nome'], 'quantidade': 1}
        ]
      });
      final maximumId = orders.fold<int>(0,
          (value, order) => order['id'] > value ? order['id'] as int : value);
      expect(newOrder['id'], greaterThan(maximumId));
      // The rehearsal write exists only in memory, never in the delivered copy.
      await expectLater(BackupService.restoreEmpty(targetStore, bytes, key),
          throwsA(isA<BusinessError>()));
      await backup.rename('${folder.path}/importacao.pastelbackup');
      await File('${folder.path}/chave-recuperacao.txt')
          .writeAsString(key, flush: true);
      report['tablet_restore_verified'] = true;
      report['verified_orders'] = orders.length;
      report['verified_items'] = items;
      report['verified_total_centavos'] = total;
      await reportFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(report),
          flush: true);
    } finally {
      await source.close();
      await target.close();
    }
  },
      skip: directory == null ? 'Set MIGRATION_DIR for local export.' : false,
      timeout: const Timeout(Duration(minutes: 5)));
}
