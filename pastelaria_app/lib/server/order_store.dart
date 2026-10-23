import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';
import 'package:timezone/timezone.dart' as tz;

class BusinessError implements Exception {
  final String message;
  final int status;
  BusinessError(this.message, [this.status = 400]);
  @override
  String toString() => message;
}

/// All commands commit their result and idempotency record in one transaction.
class OrderStore {
  final Database db;
  final DateTime Function() now;
  OrderStore(this.db, {DateTime Function()? now}) : now = now ?? DateTime.now;

  static Future<void> createSchema(Database db, int version) async {
    await db.execute(
        'CREATE TABLE products (id INTEGER PRIMARY KEY, name TEXT UNIQUE NOT NULL, data TEXT NOT NULL)');
    await db.execute(
        "CREATE TABLE orders (id INTEGER PRIMARY KEY AUTOINCREMENT, day TEXT NOT NULL, status TEXT NOT NULL DEFAULT 'aberto', data TEXT NOT NULL)");
    await db.execute('CREATE INDEX orders_status ON orders(status)');
    await db.execute('CREATE INDEX orders_day ON orders(day)');
    await db.execute(
        'CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT NOT NULL)');
    await db.insert('meta', {'key': 'revision', 'value': '0'});
    await db.execute(
        'CREATE TABLE commands (id TEXT PRIMARY KEY, fingerprint TEXT NOT NULL, result TEXT NOT NULL)');
    await db.execute(
        'CREATE TABLE print_jobs (id INTEGER PRIMARY KEY AUTOINCREMENT, order_id INTEGER NOT NULL REFERENCES orders(id), status TEXT NOT NULL, second_copy INTEGER NOT NULL DEFAULT 0, error TEXT, created_at TEXT NOT NULL)');
  }

  String get day =>
      tz.TZDateTime.from(now(), tz.getLocation('America/Sao_Paulo'))
          .toIso8601String()
          .substring(0, 10);

  Future<void> seed(List<dynamic> products) async {
    await db.transaction((tx) async {
      if ((await tx.query('products', limit: 1)).isNotEmpty) return;
      for (var i = 0; i < products.length; i++) {
        final p = Map<String, dynamic>.from(products[i]);
        p['id'] = i + 1;
        p['preco'] = (p['preco_centavos'] as int) / 100;
        await tx.insert('products',
            {'id': i + 1, 'name': p['nome'], 'data': jsonEncode(p)});
      }
    });
  }

  Future<List<dynamic>> products([String? type]) async {
    final all = (await db.query('products', orderBy: 'id'))
        .map((r) => jsonDecode(r['data'] as String))
        .toList();
    return type == null ? all : all.where((p) => p['tipo'] == type).toList();
  }

  Future<Map<String, dynamic>> _order(DatabaseExecutor tx, int id) async {
    final rows = await tx.query('orders', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) throw BusinessError('Pedido não encontrado.', 404);
    return jsonDecode(rows.single['data'] as String) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> order(int id) => _order(db, id);

  Future<Map<String, dynamic>> snapshot(
          {bool today = false, bool activeOnly = false}) =>
      db.transaction((tx) async {
        final revision = int.parse(
            (await tx.query('meta', where: 'key = ?', whereArgs: ['revision']))
                .single['value'] as String);
        final conditions = <String>[
          if (today) 'day = ?',
          if (activeOnly) 'status = ?'
        ];
        final rows = await tx.query('orders',
            where: conditions.isEmpty ? null : conditions.join(' AND '),
            whereArgs: [if (today) day, if (activeOnly) 'aberto'],
            orderBy: 'id ASC');
        return {
          'revision': revision,
          'pedidos': rows.map((r) => jsonDecode(r['data'] as String)).toList()
        };
      });

  Future<Map<String, dynamic>> command(
      String id, String action, Map<String, dynamic> payload) async {
    if (id.isEmpty || id.length > 160) {
      throw BusinessError('Identificador de comando inválido.');
    }
    final fingerprint =
        sha256.convert(utf8.encode(jsonEncode([action, payload]))).toString();
    return db.transaction((tx) async {
      final previous =
          await tx.query('commands', where: 'id = ?', whereArgs: [id]);
      if (previous.isNotEmpty) {
        if (previous.single['fingerprint'] != fingerprint) {
          throw BusinessError('Comando reutilizado com dados diferentes.', 409);
        }
        return jsonDecode(previous.single['result'] as String)
            as Map<String, dynamic>;
      }
      final revision = int.parse((await tx
                  .query('meta', where: 'key = ?', whereArgs: ['revision']))
              .single['value'] as String) +
          1;
      final result = action == 'create'
          ? await _create(tx, payload, revision)
          : await _change(tx, action, payload, revision);
      await tx.update('meta', {'value': '$revision'},
          where: 'key = ?', whereArgs: ['revision']);
      await tx.insert('commands',
          {'id': id, 'fingerprint': fingerprint, 'result': jsonEncode(result)});
      return result;
    });
  }

  int _quantity(dynamic value) {
    if (value is! int || value <= 0 || value > 999) {
      throw BusinessError('Quantidade deve ser um inteiro entre 1 e 999.');
    }
    return value;
  }

  Future<Map<String, dynamic>> _create(
      Transaction tx, Map<String, dynamic> data, int revision) async {
    final orderDay = day;
    final raw = data['itens'];
    if (raw is! List || raw.isEmpty || raw.length > 200) {
      throw BusinessError('Adicione de 1 a 200 itens.');
    }
    final items = <Map<String, dynamic>>[];
    var total = 0;
    for (var i = 0; i < raw.length; i++) {
      final input = Map<String, dynamic>.from(raw[i] as Map);
      final quantity = _quantity(input['quantidade']);
      final found = await tx.query('products',
          where: 'name = ?', whereArgs: [input['produto_nome']]);
      if (found.isEmpty) {
        throw BusinessError('Produto indisponível: ${input['produto_nome']}');
      }
      final product =
          jsonDecode(found.single['data'] as String) as Map<String, dynamic>;
      if (product['tipo'] == 'ingrediente') {
        throw BusinessError('Selecione ingredientes dentro de um pastel.');
      }
      final ingredients = <String>[];
      var cents = product['preco_centavos'] as int;
      if (product['tipo'] == 'pastel') {
        for (final ing in (input['ingredientes'] as List? ?? [])) {
          final name = ing is String ? ing : ing['nome'] as String;
          if (ingredients.contains(name)) {
            throw BusinessError('Ingrediente repetido.');
          }
          final exists =
              await tx.query('products', where: 'name = ?', whereArgs: [name]);
          if (exists.isEmpty ||
              (jsonDecode(exists.single['data'] as String))['tipo'] !=
                  'ingrediente') {
            throw BusinessError('Ingrediente inválido: $name');
          }
          ingredients.add(name);
        }
        if (ingredients.isEmpty) {
          throw BusinessError('Escolha o recheio do pastel.');
        }
        if (ingredients.contains('Pizza') || ingredients.contains('Misto')) {
          if (ingredients.length != 1) {
            throw BusinessError('Pastel especial não pode misturar recheios.');
          }
          cents = ingredients.single == 'Pizza' ? 1500 : 2500;
        } else {
          final paid = ingredients
              .where((v) => !['Cebola', 'Cebolinha', 'Orégano'].contains(v))
              .length;
          cents = 1200 + (paid > 2 ? (paid - 2) * 300 : 0);
        }
      }
      total += cents * quantity;
      items.add({
        'item_id': i + 1,
        'produto_id': product['id'],
        'produto_nome': product['nome'],
        'produto_tipo': product['tipo'],
        'quantidade': quantity,
        'quantidade_pronta': product['tipo'] == 'pastel' ? 0 : quantity,
        'quantidade_entregue': 0,
        'quantidade_cancelada': 0,
        'preco_unitario_centavos': cents,
        'preco_unitario': cents / 100,
        'subtotal': cents * quantity / 100,
        'preco': cents * quantity / 100,
        'ingredientes': ingredients,
        'observacoes_item': (input['observacoes_item'] ?? '').toString().trim(),
      });
    }
    final hasPastel = items.any((i) => i['produto_tipo'] == 'pastel');
    final sequenceKey = '${hasPastel ? 'ticket' : 'counter'}:$orderDay';
    final seq =
        await tx.query('meta', where: 'key = ?', whereArgs: [sequenceKey]);
    final last = seq.isEmpty ? 0 : int.parse(seq.single['value'] as String);
    final ticket = hasPastel ? last % 99 + 1 : last - 1;
    await tx.insert('meta', {'key': sequenceKey, 'value': '$ticket'},
        conflictAlgorithm: ConflictAlgorithm.replace);
    final id = await tx.insert('orders', {'day': orderDay, 'data': '{}'});
    for (final item in items) {
      item['pedido_id'] = id;
      item['numero_pedido'] = ticket;
    }
    final order = <String, dynamic>{
      'id': id,
      'pedido_id': id,
      'numero_pedido': ticket,
      'data_hora_pedido': now().toUtc().toIso8601String(),
      'reset_data': orderDay,
      'observacoes': (data['observacoes_pedido'] ?? '').toString().trim(),
      'total_centavos': total,
      'total_pedido': total / 100,
      'status': 'aberto',
      'revision': revision,
      'itens': items,
    };
    _derive(order);
    await tx.update('orders', {'data': jsonEncode(order)},
        where: 'id = ?', whereArgs: [id]);
    await tx.insert('print_jobs', {
      'order_id': id,
      'status': 'pendente',
      'created_at': now().toUtc().toIso8601String()
    });
    return order;
  }

  Future<Map<String, dynamic>> _change(Transaction tx, String action,
      Map<String, dynamic> p, int revision) async {
    final order = await _order(tx, p['pedido_id'] as int);
    if (p['expected_revision'] != order['revision']) {
      throw BusinessError(
          'Pedido atualizado em outro tablet. Confira os saldos e tente novamente.',
          409);
    }
    if (action == 'reprint') {
      await tx.insert('print_jobs', {
        'order_id': order['id'],
        'status': 'pendente',
        'second_copy': 1,
        'created_at': now().toUtc().toIso8601String()
      });
    } else {
      if (order['status'] != 'aberto') {
        throw BusinessError('Pedido já finalizado ou cancelado.', 409);
      }
      final items = order['itens'] as List;
      if (action == 'cancel') {
        if (items.any((i) =>
            i['quantidade_pronta'] > 0 && i['produto_tipo'] == 'pastel' ||
            i['quantidade_entregue'] > 0)) {
          throw BusinessError(
              'Cancelamento após preparo/entrega exige conferência; operação não disponível nesta versão.',
              409);
        }
        for (final item in items) {
          item['quantidade_cancelada'] = item['quantidade'];
          item['quantidade_pronta'] = 0;
        }
        order['status'] = 'cancelado';
        await tx.update(
            'print_jobs',
            {
              'status': 'cancelado',
              'error': 'Pedido cancelado antes do envio.'
            },
            where: 'order_id = ? AND status = ?',
            whereArgs: [order['id'], 'pendente']);
      } else if (action == 'ready' || action == 'deliver') {
        final matching = items.where((i) => i['item_id'] == p['item_id']);
        if (matching.isEmpty) throw BusinessError('Item não encontrado.', 404);
        final item = matching.single;
        final count = _quantity(p['quantidade']);
        final available = action == 'ready'
            ? item['quantidade'] -
                item['quantidade_cancelada'] -
                item['quantidade_pronta']
            : item['quantidade_pronta'] - item['quantidade_entregue'];
        if (count > available) {
          throw BusinessError('Quantidade maior que o saldo disponível.', 409);
        }
        final key =
            action == 'ready' ? 'quantidade_pronta' : 'quantidade_entregue';
        item[key] = (item[key] as int) + count;
      } else {
        throw BusinessError('Operação não suportada.');
      }
    }
    order['revision'] = revision;
    _derive(order);
    await tx.update(
        'orders', {'data': jsonEncode(order), 'status': order['status']},
        where: 'id = ?', whereArgs: [order['id']]);
    return order;
  }

  void _derive(Map<String, dynamic> order) {
    final items = order['itens'] as List;
    for (final item in items) {
      final q = item['quantidade'] - item['quantidade_cancelada'];
      item['status_item'] = q == 0
          ? 'cancelado'
          : item['quantidade_entregue'] == q
              ? 'entregue'
              : item['quantidade_pronta'] == q
                  ? 'pronto'
                  : item['quantidade_pronta'] > 0
                      ? 'em_preparacao'
                      : 'aguardando';
    }
    if (order['status'] != 'cancelado') {
      order['status'] = items.every(
              (i) => ['entregue', 'cancelado'].contains(i['status_item']))
          ? 'fechado'
          : 'aberto';
    }
  }
}
