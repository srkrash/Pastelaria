import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';
import 'package:timezone/timezone.dart' as tz;
import '../models/pricing_rules.dart';
import '../models/pastel_extra.dart';

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

  Future<PricingRules> _pricing(DatabaseExecutor tx) async {
    final rows = await tx
        .query('meta', where: 'key = ?', whereArgs: ['pricing_rules_v1']);
    return rows.isEmpty
        ? const PricingRules()
        : PricingRules.fromJson(
            jsonDecode(rows.single['value'] as String) as Map);
  }

  Future<int> _catalogRevision(DatabaseExecutor tx) async {
    final rows = await tx
        .query('meta', where: 'key = ?', whereArgs: ['catalog_revision']);
    return rows.isEmpty ? 0 : int.parse(rows.single['value'] as String);
  }

  Future<Map<String, dynamic>> _catalog(DatabaseExecutor tx) async => {
        'catalog_revision': await _catalogRevision(tx),
        'rules': (await _pricing(tx)).toJson(),
        'products': (await tx.query('products', orderBy: 'id'))
            .map((r) => jsonDecode(r['data'] as String))
            .toList(),
      };
  Future<Map<String, dynamic>> priceCatalog() => db.transaction(_catalog);

  Future<Map<String, dynamic>> _updatePrices(
      Transaction tx, Map<String, dynamic> payload, int revision) async {
    if (payload['expected_catalog_revision'] != await _catalogRevision(tx)) {
      throw BusinessError(
          'Os preços foram alterados em outro tablet. Recarregue antes de editar.',
          409);
    }
    final ruleData = payload['rules'];
    const keys = [
      'base_centavos',
      'adicional_centavos',
      'pizza_centavos',
      'misto_centavos'
    ];
    bool valid(dynamic value) => value is int && value >= 0 && value <= 999999;
    if (ruleData is! Map ||
        ruleData.length != keys.length ||
        keys.any((key) => !valid(ruleData[key]))) {
      throw BusinessError(
          'Informe preços em centavos, entre zero e R\$ 9.999,99.');
    }
    final changes = payload['products'];
    if (changes is! List || changes.length > 500) {
      throw BusinessError('Lista de preços inválida.');
    }
    final seen = <int>{};
    final audit = <Map<String, dynamic>>[];
    final oldRules = (await _pricing(tx)).toJson();
    for (final raw in changes) {
      if (raw is! Map ||
          raw['id'] is! int ||
          !seen.add(raw['id'] as int) ||
          !valid(raw['preco_centavos'])) {
        throw BusinessError('Produto ou preço inválido ou repetido.');
      }
      final rows =
          await tx.query('products', where: 'id = ?', whereArgs: [raw['id']]);
      if (rows.isEmpty) throw BusinessError('Produto não encontrado.', 404);
      final product =
          jsonDecode(rows.single['data'] as String) as Map<String, dynamic>;
      if (!['bebida', 'salgado'].contains(product['tipo'])) {
        throw BusinessError(
            'Use os campos de regras para alterar os preços dos pastéis.');
      }
      audit.add({
        'id': raw['id'],
        'antes_centavos': product['preco_centavos'],
        'depois_centavos': raw['preco_centavos']
      });
      product['preco_centavos'] = raw['preco_centavos'];
      product['preco'] = (raw['preco_centavos'] as int) / 100;
      await tx.update('products', {'data': jsonEncode(product)},
          where: 'id = ?', whereArgs: [raw['id']]);
    }
    for (final entry in {
      'pricing_rules_v1': jsonEncode(ruleData),
      'catalog_revision': '$revision'
    }.entries) {
      await tx.insert('meta', {'key': entry.key, 'value': entry.value},
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    return {
      ...await _catalog(tx),
      'changed_at': now().toUtc().toIso8601String(),
      'previous_rules': oldRules,
      'price_changes': audit
    };
  }

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
        final result = jsonDecode(previous.single['result'] as String)
            as Map<String, dynamic>;
        if (result.containsKey('removed_test_order_id')) {
          throw BusinessError(
              'Pedido de teste removido durante a limpeza.', 410);
        }
        return result;
      }
      final revision = int.parse((await tx
                  .query('meta', where: 'key = ?', whereArgs: ['revision']))
              .single['value'] as String) +
          1;
      final result = action == 'clear_today_tests'
          ? await _clearTodayTests(tx, payload, revision)
          : action == 'update_prices'
              ? await _updatePrices(tx, payload, revision)
              : action == 'create'
                  ? await _create(tx, payload, revision)
                  : await _change(tx, action, payload, revision);
      await tx.update('meta', {'value': '$revision'},
          where: 'key = ?', whereArgs: ['revision']);
      await tx.insert('commands',
          {'id': id, 'fingerprint': fingerprint, 'result': jsonEncode(result)});
      return result;
    });
  }

  Future<Map<String, dynamic>> _clearTodayTests(
      Transaction tx, Map<String, dynamic> payload, int revision) async {
    if (payload['confirmation'] != 'APAGAR TESTES DE HOJE' ||
        payload['expected_day'] != day ||
        payload['expected_revision'] != revision - 1) {
      throw BusinessError(
          'Data ou pedidos alterados. Confira novamente antes de apagar.', 409);
    }
    final rows = await tx.query('orders',
        columns: ['id'], where: 'day = ?', whereArgs: [day]);
    if (rows.isEmpty || payload['expected_count'] != rows.length) {
      throw BusinessError(
          'Quantidade de pedidos alterada. Confira novamente.', 409);
    }
    final sending = await tx.query('print_jobs',
        columns: ['id'],
        where: 'status = ?',
        whereArgs: ['enviando'],
        limit: 1);
    if (sending.isNotEmpty) {
      throw BusinessError('Aguarde o envio de impressão terminar.', 409);
    }
    final ids = rows.map((row) => row['id'] as int).toSet();
    // Retain command IDs/fingerprints as tombstones so an offline client cannot
    // recreate a removed test order by retrying the original create command.
    for (final command in await tx.query('commands')) {
      final result = jsonDecode(command['result'] as String) as Map;
      if (ids.contains(result['id'])) {
        await tx.update(
            'commands',
            {
              'result': jsonEncode({
                'removed_test_order_id': result['id'],
              })
            },
            where: 'id = ?',
            whereArgs: [command['id']]);
      }
    }
    await tx.delete('print_jobs',
        where: 'order_id IN (SELECT id FROM orders WHERE day = ?)',
        whereArgs: [day]);
    await tx.delete('orders', where: 'day = ?', whereArgs: [day]);
    // Keep catalog, IDs and daily sequence; deleting test orders is not a
    // request to reuse IDs or reset the ticket counter.
    return {'deleted_count': rows.length, 'day': day, 'revision': revision};
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
    final pricing = await _pricing(tx);
    final catalogChanged = await _catalogRevision(tx) > 0;
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
      List<PastelExtra> extras;
      try {
        extras = PastelExtra.parse(input['adicionais']);
      } on FormatException catch (error) {
        throw BusinessError(error.message);
      }
      if (extras.isNotEmpty && product['tipo'] != 'pastel') {
        throw BusinessError(
            'Recheio adicional disponível somente para pastel.');
      }
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
          cents = pricing.pastel(ingredients);
        } else {
          cents = pricing.pastel(ingredients);
        }
      }
      final baseCents = cents;
      cents += extraUnitCents(extras);
      if ((input.containsKey('preco_esperado_centavos') &&
              input['preco_esperado_centavos'] != cents) ||
          ((catalogChanged || extras.isNotEmpty) &&
              !input.containsKey('preco_esperado_centavos'))) {
        throw BusinessError(
            'Os preços mudaram. Atualize os preços da comanda e confira o total antes de confirmar. Tablets antigos precisam do APK atualizado.',
            422);
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
        'preco_base_unitario_centavos': baseCents,
        'adicionais': extras.map((extra) => extra.toJson()).toList(),
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
      } else if (action == 'deliver_all') {
        if (items.any((i) =>
            i['quantidade_pronta'] <
            i['quantidade'] - i['quantidade_cancelada'])) {
          throw BusinessError(
              'Aguarde todos os pastéis ficarem prontos antes de entregar o pedido inteiro.',
              409);
        }
        for (final item in items) {
          item['quantidade_entregue'] =
              item['quantidade'] - item['quantidade_cancelada'];
        }
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
