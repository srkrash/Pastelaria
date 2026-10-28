import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:pastelaria_app/server/order_store.dart';
import 'package:pastelaria_app/server/local_server.dart';
import 'package:pastelaria_app/server/backup_service.dart';

void main() {
  late Database db;
  late OrderStore store;
  var time = DateTime.utc(2026, 10, 23, 18);
  var command = 0;
  final payload = <String, dynamic>{
    'itens': [
      {
        'produto_nome': 'Pastel',
        'quantidade': 5,
        'ingredientes': [
          {'nome': 'Carne'}
        ]
      }
    ]
  };
  Future<Map<String, dynamic>> create() =>
      store.command('create-${command++}', 'create', payload);
  Future<Map<String, dynamic>> change(
          Map<String, dynamic> order, String action, int count,
          {String? id}) =>
      store.command(id ?? 'change-${command++}', action, {
        'pedido_id': order['id'],
        'item_id': 1,
        'quantidade': count,
        'expected_revision': order['revision']
      });

  setUpAll(() {
    tz.initializeTimeZones();
    sqfliteFfiInit();
  });
  setUp(() async {
    time = DateTime.utc(2026, 10, 23, 18);
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath,
        options: OpenDatabaseOptions(
            version: 1,
            onConfigure: (db) => db.execute('PRAGMA foreign_keys=ON'),
            onCreate: OrderStore.createSchema));
    store = OrderStore(db, now: () => time);
    await store.seed([
      {'nome': 'Pastel', 'tipo': 'pastel', 'preco_centavos': 0},
      {'nome': 'Carne', 'tipo': 'ingrediente', 'preco_centavos': 0},
      {'nome': 'Água', 'tipo': 'bebida', 'preco_centavos': 200}
    ]);
  });
  tearDown(() => db.close());

  test('preço validado no servidor, criação idempotente e uma impressão',
      () async {
    final a = await store.command('same', 'create', payload);
    final b = await store.command('same', 'create', payload);
    expect(a['id'], b['id']);
    expect(a['total_centavos'], 6000);
    expect((await db.query('orders')).length, 1);
    expect((await db.query('print_jobs')).length, 1);
    await expectLater(store.command('same', 'create', {'itens': []}),
        throwsA(isA<BusinessError>()));
  });
  test('limpeza remove só testes de hoje, preserva catálogo e bloqueia reenvio',
      () async {
    time = DateTime.utc(2026, 10, 22, 18);
    final previous = await create();
    time = DateTime.utc(2026, 10, 23, 18);
    final today = await store.command('test-to-remove', 'create', payload);
    final snapshot = await store.snapshot(today: true);
    final products = await store.products();
    final cleanup = {
      'confirmation': 'APAGAR TESTES DE HOJE',
      'expected_day': store.day,
      'expected_revision': snapshot['revision'],
      'expected_count': 1,
    };
    final result =
        await store.command('clear-tests', 'clear_today_tests', cleanup);
    expect(result['deleted_count'], 1);
    expect((await store.snapshot(today: true))['pedidos'], isEmpty);
    expect((await db.query('orders')).single['id'], previous['id']);
    expect((await db.query('print_jobs')).single['order_id'], previous['id']);
    expect(await store.products(), products);
    expect(await store.command('clear-tests', 'clear_today_tests', cleanup),
        result);
    await expectLater(store.command('test-to-remove', 'create', payload),
        throwsA(isA<BusinessError>().having((e) => e.status, 'status', 410)));
    final next = await create();
    expect(next['id'], greaterThan(today['id'] as int));
    expect(next['numero_pedido'], 2);
  });
  test('limpeza rejeita data, revisão, quantidade e confirmação divergentes',
      () async {
    await create();
    final snapshot = await store.snapshot(today: true);
    final cleanup = <String, dynamic>{
      'confirmation': 'APAGAR TESTES DE HOJE',
      'expected_day': store.day,
      'expected_revision': snapshot['revision'],
      'expected_count': 1,
    };
    for (final change in [
      {'expected_day': '2026-10-22'},
      {'expected_revision': 0},
      {'expected_count': 2},
      {'confirmation': ''},
    ]) {
      await expectLater(
          store.command('invalid-clear-${command++}', 'clear_today_tests',
              {...cleanup, ...change}),
          throwsA(isA<BusinessError>()));
    }
    expect((await db.query('orders')), hasLength(1));
    expect((await db.query('print_jobs')), hasLength(1));
  });
  test('limpeza não apaga trabalho em envio', () async {
    await create();
    final snapshot = await store.snapshot(today: true);
    await db.update('print_jobs', {'status': 'enviando'});
    await expectLater(
        store.command('busy-clear', 'clear_today_tests', {
          'confirmation': 'APAGAR TESTES DE HOJE',
          'expected_day': store.day,
          'expected_revision': snapshot['revision'],
          'expected_count': 1,
        }),
        throwsA(isA<BusinessError>()));
    expect((await db.query('orders')), hasLength(1));
  });
  test('5 solicitados, 2 prontos e 1 entregue; restante permanece ativo',
      () async {
    var o = await create();
    o = await change(o, 'ready', 2);
    o = await change(o, 'deliver', 1);
    final i = (o['itens'] as List).single;
    expect(i['quantidade'] - i['quantidade_pronta'], 3);
    expect(i['quantidade_pronta'] - i['quantidade_entregue'], 1);
    expect(i['quantidade_entregue'], 1);
    expect(o['status'], 'aberto');
    o = await change(o, 'ready', 3);
    expect(o['status'], 'aberto');
    o = await change(o, 'deliver', 4);
    expect(o['status'], 'fechado');
  });
  test('entrega completa exige preparo, entrega saldos mistos e é idempotente',
      () async {
    var order = await store.command('mixed-bulk', 'create', {
      'itens': [
        ...payload['itens'] as List,
        {'produto_nome': 'Água', 'quantidade': 3},
      ],
    });
    Future<Map<String, dynamic>> bulk(String id) =>
        store.command(id, 'deliver_all', {
          'pedido_id': order['id'],
          'expected_revision': order['revision'],
        });
    await expectLater(bulk('not-ready'), throwsA(isA<BusinessError>()));
    expect(
        (await store.order(order['id']))['itens'][1]['quantidade_entregue'], 0);
    order = await change(order, 'ready', 2);
    await expectLater(bulk('part-ready'), throwsA(isA<BusinessError>()));
    order = await change(order, 'deliver', 1);
    order = await change(order, 'ready', 3);
    final request = {
      'pedido_id': order['id'],
      'expected_revision': order['revision']
    };
    final done = await store.command('bulk-once', 'deliver_all', request);
    expect(done['status'], 'fechado');
    expect(done['itens'][0]['quantidade_pronta'], 5);
    expect(done['itens'][0]['quantidade_entregue'], 5);
    expect(done['itens'][1]['quantidade_entregue'], 3);
    expect(await store.command('bulk-once', 'deliver_all', request), done);
    await expectLater(store.command('bulk-other', 'deliver_all', request),
        throwsA(isA<BusinessError>()));
    expect(
        (await store.order(order['id']))['itens'][0]['quantidade_entregue'], 5);
  });
  test(
      'entrega completa de balcão não cria preparo nem entrega unidades canceladas',
      () async {
    var order = await store.command('counter-bulk', 'create', {
      'itens': [
        {'produto_nome': 'Água', 'quantidade': 3}
      ],
    });
    // Valid state from partial cancellation/history: only two active units.
    order['itens'][0]['quantidade_cancelada'] = 1;
    order['itens'][0]['quantidade_pronta'] = 2;
    await db.update('orders', {'data': jsonEncode(order)},
        where: 'id = ?', whereArgs: [order['id']]);
    order = await store.command('counter-done', 'deliver_all', {
      'pedido_id': order['id'],
      'expected_revision': order['revision'],
    });
    expect(order['status'], 'fechado');
    expect(order['itens'][0]['quantidade_entregue'], 2);
    expect(order['itens'][0]['quantidade_pronta'], 2);
    expect(order['itens'][0]['quantidade_cancelada'], 1);
  });
  test('dois clientes não entregam a mesma última unidade', () async {
    var o = await create();
    o = await change(o, 'ready', 1);
    final attempts = await Future.wait([
      change(o, 'deliver', 1).then<Object>((v) => v, onError: (Object e) => e),
      change(o, 'deliver', 1).then<Object>((v) => v, onError: (Object e) => e)
    ]);
    expect(attempts.whereType<BusinessError>().length, 1);
    expect(
        ((await store.order(o['id'] as int))['itens'] as List)
            .single['quantidade_entregue'],
        1);
  });
  test('reenvio parcial não incrementa contador duas vezes', () async {
    final o = await create();
    final a = await change(o, 'ready', 2, id: 'ready-retry');
    final b = await change(o, 'ready', 2, id: 'ready-retry');
    expect(a, b);
    expect(
        ((await store.order(o['id'] as int))['itens'] as List)
            .single['quantidade_pronta'],
        2);
  });
  test('não entrega o que não está pronto nem aceita quantidade inválida',
      () async {
    final o = await create();
    await expectLater(change(o, 'deliver', 1), throwsA(isA<BusinessError>()));
    await expectLater(change(o, 'ready', 6), throwsA(isA<BusinessError>()));
    await expectLater(change(o, 'ready', -1), throwsA(isA<BusinessError>()));
    expect((await store.order(o['id'] as int))['revision'], o['revision']);
  });
  test('ciclo 98, 99, 1 preserva histórico e IDs', () async {
    final orders = <Map<String, dynamic>>[];
    for (var i = 0; i < 100; i++) {
      orders.add(await create());
    }
    expect(orders[97]['numero_pedido'], 98);
    expect(orders[98]['numero_pedido'], 99);
    expect(orders[99]['numero_pedido'], 1);
    expect(orders.map((o) => o['id']).toSet().length, 100);
  });
  test(
      'reinicia pela data de São Paulo; reabrir no mesmo dia conserva sequência',
      () async {
    time = DateTime.utc(2026, 10, 24, 2, 59);
    expect((await create())['numero_pedido'], 1);
    store = OrderStore(db, now: () => time);
    expect((await create())['numero_pedido'], 2);
    time = DateTime.utc(2026, 10, 24, 3);
    expect((await create())['numero_pedido'], 1);
    expect(((await store.snapshot())['pedidos'] as List).length, 3);
  });
  test('falha na criação reverte pedido, senha e impressão', () async {
    await expectLater(
        store.command('bad', 'create', {
          'itens': [
            {'produto_nome': 'Pastel', 'quantidade': 0}
          ]
        }),
        throwsA(isA<BusinessError>()));
    expect((await create())['numero_pedido'], 1);
    expect((await db.query('print_jobs')).length, 1);
  });
  test('pronta entrega já disponível e sem avançar senha de pastel', () async {
    final o = await store.command('drink', 'create', {
      'itens': [
        {'produto_nome': 'Água', 'quantidade': 2}
      ]
    });
    expect(o['numero_pedido'], -1);
    expect((o['itens'] as List).single['quantidade_pronta'], 2);
    expect((await create())['numero_pedido'], 1);
  });
  test('cancelamento não destrói quantidades já preparadas', () async {
    var o = await create();
    o = await change(o, 'ready', 1);
    await expectLater(
        store.command('cancel', 'cancel',
            {'pedido_id': o['id'], 'expected_revision': o['revision']}),
        throwsA(isA<BusinessError>()));
    expect((await store.order(o['id'] as int))['status'], 'aberto');
  });
  test(
      'preços por HTTP: dois clientes reconciliam catálogo e rejeitam edição antiga',
      () async {
    final server = LocalServer(store, 'test-connection-key-12345');
    await server.start(address: InternetAddress.loopbackIPv4, port: 0);
    final clients = [HttpClient(), HttpClient()];
    final ws = await WebSocket.connect('ws://127.0.0.1:${server.port}/events',
        headers: {'Authorization': 'Bearer test-connection-key-12345'});
    final events = StreamIterator(ws);
    Future<(int, Map<String, dynamic>)> request(int client, String path,
        {Map<String, dynamic>? body, bool authorized = true}) async {
      final uri = Uri.parse('http://127.0.0.1:${server.port}$path');
      final req = body == null
          ? await clients[client].getUrl(uri)
          : await clients[client].postUrl(uri);
      if (authorized) {
        req.headers.set('Authorization', 'Bearer test-connection-key-12345');
      }
      if (body != null) {
        req.headers.contentType = ContentType.json;
        req.write(jsonEncode(body));
      }
      final response = await req.close();
      return (
        response.statusCode,
        jsonDecode(await utf8.decoder.bind(response).join())
            as Map<String, dynamic>
      );
    }

    try {
      await events.moveNext(); // Initial refresh.
      expect((await request(0, '/catalogo/precos', authorized: false)).$1, 401);
      final before = (await request(1, '/catalogo/precos')).$2;
      final update = {
        'command_id': 'price-http',
        'action': 'update_prices',
        'payload': {
          'expected_catalog_revision': before['catalog_revision'],
          'rules': {
            'base_centavos': 1300,
            'adicional_centavos': 400,
            'pizza_centavos': 1800,
            'misto_centavos': 2800
          },
          'products': [
            {'id': 3, 'preco_centavos': 450}
          ],
        }
      };
      expect((await request(0, '/commands', body: update)).$1, 200);
      expect(
          await events.moveNext().timeout(const Duration(seconds: 3)), isTrue);
      expect(jsonDecode(events.current as String)['type'], 'refresh');
      final after = (await request(1, '/catalogo/precos')).$2;
      expect(after['rules']['base_centavos'], 1300);
      expect(
          (after['products'] as List)
              .firstWhere((p) => p['id'] == 3)['preco_centavos'],
          450);
      expect(
          (await request(1, '/commands',
                  body: {...update, 'command_id': 'stale-price-http'}))
              .$1,
          409);
      final staleOrder = {
        'command_id': 'stale-quote-http',
        'action': 'create',
        'payload': {
          'itens': [
            {
              'produto_nome': 'Água',
              'quantidade': 1,
              'preco_esperado_centavos': 200
            }
          ],
        }
      };
      expect((await request(1, '/commands', body: staleOrder)).$1, 422);
      expect(await db.query('orders'), isEmpty);
      expect(await db.query('print_jobs'), isEmpty);
    } finally {
      await events.cancel();
      await ws.close();
      for (final client in clients) {
        client.close(force: true);
      }
      await server.stop();
    }
  });
  test('HTTP e dois WebSockets: entrega não remove pedido vizinho', () async {
    final server = LocalServer(store, 'test-connection-key-12345');
    await server.start(address: InternetAddress.loopbackIPv4, port: 0);
    final clients = [HttpClient(), HttpClient()];
    final sockets = <WebSocket>[];
    final events = [0, 0];
    Future<Map<String, dynamic>> post(
        int client, String action, Map<String, dynamic> payload,
        {bool allowConflict = false}) async {
      final req = await clients[client]
          .postUrl(Uri.parse('http://127.0.0.1:${server.port}/commands'));
      req.headers.set('Authorization', 'Bearer test-connection-key-12345');
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode({
        'command_id': 'http-${command++}',
        'action': action,
        'payload': payload
      }));
      final response = await req.close();
      expect(response.statusCode, allowConflict ? isIn([200, 409]) : 200);
      final result = jsonDecode(await utf8.decoder.bind(response).join())
          as Map<String, dynamic>;
      if (allowConflict) result['_http_status'] = response.statusCode;
      return result;
    }

    Future<dynamic> get(int client, String path,
        {bool authorized = true}) async {
      final req = await clients[client]
          .getUrl(Uri.parse('http://127.0.0.1:${server.port}$path'));
      if (authorized) {
        req.headers.set('Authorization', 'Bearer test-connection-key-12345');
      }
      final res = await req.close();
      final body = await utf8.decoder.bind(res).join();
      if (!authorized) {
        expect(res.statusCode, 401);
        return null;
      }
      expect(res.statusCode, 200);
      return jsonDecode(body);
    }

    try {
      for (var i = 0; i < 2; i++) {
        sockets.add(await WebSocket.connect(
            'ws://127.0.0.1:${server.port}/events',
            headers: {'Authorization': 'Bearer test-connection-key-12345'}));
        final clientIndex = i;
        sockets.last.listen((_) {
          events[clientIndex]++;
        });
      }
      await get(0, '/snapshot', authorized: false);
      final withExtra = jsonDecode(jsonEncode(payload)) as Map<String, dynamic>;
      withExtra['itens'][0]['adicionais'] = [
        {'nome': 'Queijo extra', 'preco_centavos': 300}
      ];
      withExtra['itens'][0]['preco_esperado_centavos'] = 1500;
      var first = await post(0, 'create', withExtra);
      final fromOtherClient = await get(1, '/pedidos/${first['id']}');
      expect(fromOtherClient['total_centavos'], 7500);
      expect(fromOtherClient['itens'][0]['adicionais'], [
        {'nome': 'Queijo extra', 'preco_centavos': 300}
      ]);
      final second = await post(1, 'create', payload);
      first = await post(0, 'ready', {
        'pedido_id': first['id'],
        'item_id': 1,
        'quantidade': 5,
        'expected_revision': first['revision']
      });
      final delivery = {
        'pedido_id': first['id'],
        'expected_revision': first['revision']
      };
      final attempts = await Future.wait([
        post(0, 'deliver_all', delivery, allowConflict: true),
        post(1, 'deliver_all', delivery, allowConflict: true),
      ]);
      expect(
          attempts.map((r) => r['_http_status']).toList()..sort(), [200, 409]);
      expect(
          (await store.order(first['id']))['itens'][0]['quantidade_entregue'],
          5);
      final a = await get(0, '/snapshot');
      final b = await get(1, '/snapshot');
      expect(a, b);
      expect(events[0], greaterThanOrEqualTo(4));
      expect(events[1], greaterThanOrEqualTo(4));
      expect(
          (a['pedidos'] as List)
              .where((o) => o['status'] == 'aberto')
              .map((o) => o['id']),
          [second['id']]);
    } finally {
      for (final ws in sockets) {
        await ws.close();
      }
      for (final client in clients) {
        client.close(force: true);
      }
      await server.stop();
    }
  });

  test(
      'backup criptografado restaura saldos, sequência e suspende impressão antiga',
      () async {
    var o = await create();
    o = await change(o, 'ready', 2);
    o = await change(o, 'deliver', 1);
    final directory =
        await Directory.systemTemp.createTemp('pastelaria-backup-test-');
    final key = BackupService.newKey();
    Database? restoredDb;
    try {
      final backup = await BackupService.create(store, directory, key);
      final bytes = await backup.readAsBytes();
      expect(utf8.decode(bytes), isNot(contains('Carne')));
      await expectLater(BackupService.decode(bytes, BackupService.newKey()),
          throwsA(anything));
      restoredDb = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath,
          options: OpenDatabaseOptions(
              singleInstance: false,
              version: 1,
              onConfigure: (db) => db.execute('PRAGMA foreign_keys=ON'),
              onCreate: OrderStore.createSchema));
      final restored = OrderStore(restoredDb, now: () => time);
      await BackupService.restoreEmpty(restored, bytes, key);
      expect(await restored.order(o['id'] as int), o);
      expect(
          (await restoredDb.query('print_jobs')).single['status'], 'incerto');
      expect(
          (await restored.command(
              'after-restore', 'create', payload))['numero_pedido'],
          2);
      await expectLater(BackupService.restoreEmpty(restored, bytes, key),
          throwsA(isA<BusinessError>()));
    } finally {
      await restoredDb?.close();
      expect(directory.parent.resolveSymbolicLinksSync(),
          Directory.systemTemp.resolveSymbolicLinksSync());
      expect(directory.uri.pathSegments.where((s) => s.isNotEmpty).last,
          startsWith('pastelaria-backup-test-'));
      await directory.delete(recursive: true);
    }
  });
  test('backup corrompido falha na autenticação', () async {
    final key = BackupService.newKey();
    final encoded =
        await BackupService.encode({'schema': 1, 'tables': {}}, key);
    final envelope = jsonDecode(utf8.decode(encoded)) as Map<String, dynamic>;
    final cipher = base64Decode(envelope['ciphertext'] as String);
    cipher[0] ^= 1;
    envelope['ciphertext'] = base64Encode(cipher);
    await expectLater(
        BackupService.decode(utf8.encode(jsonEncode(envelope)), key),
        throwsA(anything));
  });
}
