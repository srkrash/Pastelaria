import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:pastelaria_app/server/bi_service.dart';
import 'package:pastelaria_app/server/local_server.dart';
import 'package:pastelaria_app/server/order_store.dart';
import 'package:pastelaria_app/screens/bi_screen.dart';
import 'package:pastelaria_app/services/api_service.dart';
import 'package:pastelaria_app/ui/app_ui.dart';

Map<String, dynamic> order(int id, String day,
        {int unit = 1200,
        int quantity = 2,
        int cancelled = 0,
        String status = 'fechado',
        bool legacy = false,
        String? instant,
        List<String> ingredients = const ['Carne', 'Queijo']}) =>
    {
      'id': id,
      'pedido_id': id,
      '_day': day,
      'reset_data': day,
      'status': status,
      'data_hora_pedido': instant ?? '${day}T21:00:00Z',
      'total_centavos': unit * quantity,
      if (legacy) 'legacy': {'status': 'aberto'},
      'itens': [
        {
          'produto_nome': 'Pastel',
          'produto_tipo': 'pastel',
          'quantidade': quantity,
          'quantidade_cancelada': cancelled,
          'preco_unitario_centavos': unit,
          'ingredientes': ingredients,
        }
      ],
    };

Map<String, dynamic> response({bool empty = false}) {
  final current = BiService.summarize(empty ? [] : [order(1, '2026-10-28')],
      DateTime.utc(2026, 10, 28), DateTime.utc(2026, 10, 28));
  return {
    'from': '2026-10-28',
    'to': '2026-10-28',
    'days': 1,
    'previous_from': '2026-10-27',
    'previous_to': '2026-10-27',
    'generated_at': '2026-10-28T21:00:00Z',
    'current': current,
    'previous': BiService.summarize(
        [], DateTime.utc(2026, 10, 27), DateTime.utc(2026, 10, 27))
  };
}

class BiApi extends ApiService {
  bool fail = false;
  bool empty;
  final ranges = <String>[];
  BiApi({this.empty = false});
  @override
  Future<Map<String, dynamic>> getBi(String from, String to) async {
    ranges.add('$from/$to');
    if (fail) throw ApiException('Sem conexão com o principal.', 0);
    return response(empty: empty);
  }
}

// Invoke the base factory explicitly: widget-test registration installs a mock
// HttpOverrides globally, while this integration test needs actual LAN sockets.
class RealHttp extends HttpOverrides {}

void main() {
  setUpAll(() {
    tz.initializeTimeZones();
    sqfliteFfiInit();
  });

  test(
      'centavos, cancelamento parcial e total, ticket e combinações sem duplicar valor',
      () {
    final data = BiService.summarize([
      order(1, '2026-10-28',
          quantity: 3, cancelled: 1, unit: 1234, legacy: true),
      order(2, '2026-10-28',
          quantity: 1,
          unit: 1234,
          status: 'aberto',
          ingredients: ['Queijo', 'Carne']),
      order(3, '2026-10-28', quantity: 5, unit: 1000, status: 'cancelado'),
    ], DateTime.utc(2026, 10, 28), DateTime.utc(2026, 10, 28));
    expect(data['value_centavos'], 3702);
    expect(data['ticket_centavos'], 1851);
    expect(data['orders'], 2);
    expect(data['quantity'], 3);
    expect(data['cancelled_orders'], 1);
    expect(data['cancelled_value_centavos'], 6234);
    expect(data['legacy_orders'], 1);
    expect(data['open_orders'], 1);
    expect(data['closed_orders'], 1);
    expect((data['flavors'] as List).single['quantity'], 3);
    expect((data['flavors'] as List).single['value_centavos'], 3702);
  });

  test('hora de São Paulo, dias sem movimento e agrupamentos nas bordas', () {
    final data = BiService.summarize([
      order(1, '2026-10-31', instant: '2026-11-01T02:30:00Z'),
      order(2, '2026-11-02'),
    ], DateTime.utc(2026, 10, 31), DateTime.utc(2026, 11, 2));
    expect((data['hourly'] as List)[23]['orders'], 1);
    expect((data['daily'] as List)[1]['value_centavos'], 0);
    expect((data['weekly'] as List).length, 2);
    expect((data['monthly'] as List).map((r) => r['value_centavos']),
        [2400, 2400]);
    expect((data['weekdays'] as List)[5]['orders'], 1);
    expect((data['hourly'] as List).length, 24);
  });

  test(
      'API autenticada, período anterior igual, limites inclusivos e leitura sem mutações',
      () async {
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath,
        options:
            OpenDatabaseOptions(version: 1, onCreate: OrderStore.createSchema));
    final store = OrderStore(db);
    final server = LocalServer(store, 'test-secret-at-least-16');
    final client = RealHttp().createHttpClient(null);
    try {
      for (final entry in [
        order(1, '2024-02-28'),
        order(2, '2024-02-29'),
        order(3, '2024-03-01'),
        order(4, '2024-03-02')
      ]) {
        await db.insert('orders', {
          'id': entry['id'],
          'day': entry['_day'],
          'status': entry['status'],
          'data': jsonEncode(entry)
        });
      }
      await server.start(address: InternetAddress.loopbackIPv4, port: 0);
      Future<HttpClientResponse> request(String query,
          {bool authenticate = true}) async {
        final req = await client
            .getUrl(Uri.parse('http://127.0.0.1:${server.port}/bi$query'));
        if (authenticate) {
          req.headers.set('Authorization', 'Bearer test-secret-at-least-16');
        }
        return req.close();
      }

      final denied =
          await request('?from=2024-03-01&to=2024-03-02', authenticate: false);
      expect(denied.statusCode, 401);
      await denied.drain<void>();
      final result = await request('?from=2024-03-01&to=2024-03-02');
      expect(result.statusCode, 200);
      final report = jsonDecode(await utf8.decoder.bind(result).join()) as Map;
      expect(report['previous_from'], '2024-02-28');
      expect(report['previous_to'], '2024-02-29');
      expect(report['current']['orders'], 2);
      expect(report['previous']['orders'], 2);
      for (final query in [
        '',
        '?from=2024-02-30&to=2024-03-01',
        '?from=2024-03-02&to=2024-03-01',
        '?from=2020-01-01&to=2026-10-28'
      ]) {
        final invalid = await request(query);
        expect(invalid.statusCode, 400);
        await invalid.drain<void>();
      }
      expect((await db.query('orders')).length, 4);
      expect(await db.query('commands'), isEmpty);
      expect(await db.query('print_jobs'), isEmpty);
      expect((await db.query('meta')).single['value'], '0');
    } finally {
      client.close(force: true);
      await server.stop();
      await db.close();
    }
  });

  test('histórico real: conciliação de todos os pedidos sem gravar no banco',
      () async {
    final db = await databaseFactoryFfi.openDatabase(
        Platform.environment['BI_VALIDATION_DB']!,
        options: OpenDatabaseOptions(readOnly: true));
    try {
      final bounds = (await db.rawQuery(
              'SELECT min(day) AS first,max(day) AS last FROM orders'))
          .single;
      final report = await BiService(OrderStore(db))
          .report(bounds['first'] as String, bounds['last'] as String);
      var total = 0, cancelled = 0, valid = 0, count = 0;
      for (final row in await db.query('orders')) {
        final data = jsonDecode(row['data'] as String) as Map;
        count++;
        if (data['status'] == 'cancelado') {
          cancelled++;
          continue;
        }
        valid++;
        total += (data['total_centavos'] as int) -
            (data['itens'] as List).fold<int>(
                0,
                (sum, item) =>
                    sum +
                    (item['quantidade_cancelada'] as int) *
                        (item['preco_unitario_centavos'] as int));
      }
      final summary = report['current'] as Map;
      expect(summary['value_centavos'], total);
      expect(summary['orders'], valid);
      expect(summary['cancelled_orders'], cancelled);
      expect(summary['legacy_orders'], count);
    } finally {
      await db.close();
    }
  },
      skip: Platform.environment['BI_VALIDATION_DB'] == null
          ? 'Local private data only.'
          : false);

  for (final size in [
    const Size(768, 1024),
    const Size(1024, 768),
    const Size(360, 800)
  ]) {
    testWidgets('BI legível sem overflow em $size com fonte ampliada',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = BiApi();
      await tester.pumpWidget(MaterialApp(
          theme: appTheme(),
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.3)),
              child: child!),
          home: BiScreen(api: api, today: DateTime(2026, 10, 28))));
      await tester.pumpAndSettle();
      expect(find.text('Valor dos pedidos'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('7 dias'));
      await tester.pumpAndSettle();
      expect(api.ranges.last, '2026-10-22/2026-10-28');
      await tester.ensureVisible(find.text('Hora'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hora'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('falha não aparece como resultado vazio; tentativa recupera',
      (tester) async {
    final api = BiApi(empty: true)..fail = true;
    await tester.pumpWidget(MaterialApp(
        theme: appTheme(),
        home: BiScreen(api: api, today: DateTime(2026, 10, 28))));
    await tester.pumpAndSettle();
    expect(find.text('Não foi possível carregar o BI.'), findsOneWidget);
    expect(find.text('Valor dos pedidos'), findsNothing);
    api.fail = false;
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.text('Valor dos pedidos'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
