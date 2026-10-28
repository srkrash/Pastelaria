import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:pastelaria_app/models/pricing_rules.dart';
import 'package:pastelaria_app/models/item_pedido.dart';
import 'package:pastelaria_app/server/order_store.dart';
import 'package:pastelaria_app/server/backup_service.dart';
import 'package:pastelaria_app/providers/pedidos_provider.dart';
import 'package:pastelaria_app/screens/product_prices_screen.dart';
import 'package:pastelaria_app/screens/novo_pedido_screen.dart';
import 'package:pastelaria_app/services/api_service.dart';
import 'package:pastelaria_app/ui/app_ui.dart';

List<Map<String, dynamic>> products() => [
      {'id': 1, 'nome': 'Pastel', 'tipo': 'pastel', 'preco_centavos': 0},
      {'id': 2, 'nome': 'Carne', 'tipo': 'ingrediente', 'preco_centavos': 0},
      {'id': 3, 'nome': 'Queijo', 'tipo': 'ingrediente', 'preco_centavos': 0},
      {'id': 4, 'nome': 'Frango', 'tipo': 'ingrediente', 'preco_centavos': 0},
      {'id': 5, 'nome': 'Pizza', 'tipo': 'ingrediente', 'preco_centavos': 1500},
      {'id': 6, 'nome': 'Misto', 'tipo': 'ingrediente', 'preco_centavos': 2500},
      {'id': 7, 'nome': 'Água', 'tipo': 'bebida', 'preco_centavos': 200},
      {'id': 8, 'nome': 'Coxinha', 'tipo': 'salgado', 'preco_centavos': 600},
    ];
Map<String, dynamic> catalog(
        {int revision = 0, PricingRules rules = const PricingRules()}) =>
    {
      'catalog_revision': revision,
      'rules': rules.toJson(),
      'products': products()
    };
Map<String, dynamic> priceChange(int revision,
        {PricingRules rules = const PricingRules(
            base: 1400, extra: 400, pizza: 1800, misto: 2800)}) =>
    {
      'expected_catalog_revision': revision,
      'rules': rules.toJson(),
      'products': [
        {'id': 7, 'preco_centavos': 350}
      ],
    };
Map<String, dynamic> sale(
        {List<String> ingredients = const ['Carne'], int? expected}) =>
    {
      'itens': [
        {
          'produto_nome': 'Pastel',
          'quantidade': 1,
          'ingredientes': ingredients,
          if (expected != null) 'preco_esperado_centavos': expected
        }
      ],
    };

class PriceApi extends ApiService {
  Map<String, dynamic> data = catalog();
  bool conflict = false;
  final saves = <Map<String, dynamic>>[];
  final orders = <Map<String, dynamic>>[];
  @override
  Future<Map<String, dynamic>> getPriceCatalog() async =>
      jsonDecode(jsonEncode(data)) as Map<String, dynamic>;
  @override
  Future<Map<String, dynamic>> snapshot() async =>
      {'revision': 1, 'pedidos': []};
  @override
  Future<Map<String, dynamic>> command(
      String action, Map<String, dynamic> payload,
      {String? commandId}) async {
    saves.add(payload);
    if (conflict) {
      throw ApiException('Os preços foram alterados em outro tablet.', 409);
    }
    data = {...data, 'catalog_revision': 1, 'rules': payload['rules']};
    for (final change in payload['products'] as List) {
      (data['products'] as List)
              .firstWhere((p) => p['id'] == change['id'])['preco_centavos'] =
          change['preco_centavos'];
    }
    return getPriceCatalog();
  }

  @override
  Future<Map<String, dynamic>> inserirPedido(
      String endpoint, Map<String, dynamic> payload) async {
    orders.add(payload);
    return {'numero_pedido': 1, 'total_pedido': 14.0};
  }
}

class RejectPriceApi extends ApiService {
  @override
  Future<Map<String, dynamic>> command(
          String action, Map<String, dynamic> payload,
          {String? commandId}) async =>
      throw ApiException('Preços mudaram', 422);
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    tz.initializeTimeZones();
  });
  test('moeda sem ponto flutuante e validação de negativos, frações e limites',
      () {
    expect(PricingRules.parsePrice('12,50'), 1250);
    expect(PricingRules.parsePrice('12.5'), 1250);
    expect(PricingRules.parsePrice('0'), 0);
    expect(PricingRules.parsePrice('9999,99'), 999999);
    for (final bad in ['', '-1', '1,234', '1.234,56', '10000', 'NaN']) {
      expect(PricingRules.parsePrice(bad), isNull);
    }
  });
  group('SQLite de preços', () {
    late Database db;
    late OrderStore store;
    setUp(() async {
      db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath,
          options: OpenDatabaseOptions(
              version: 1, onCreate: OrderStore.createSchema));
      store = OrderStore(db);
      await store.seed(products());
    });
    tearDown(() => db.close());
    test('preços novos, histórico intacto e reenvio idempotente sem duplicação',
        () async {
      final old = await store.command('old', 'create', sale());
      final first =
          await store.command('price', 'update_prices', priceChange(0));
      final replay =
          await store.command('price', 'update_prices', priceChange(0));
      expect(replay, first);
      expect(await store.order(old['id'] as int), old);
      final next = await store.command('new', 'create',
          sale(ingredients: ['Carne', 'Queijo', 'Frango'], expected: 1800));
      expect(next['total_centavos'], 1800);
      expect(
          (await store.command('pizza', 'create',
              sale(ingredients: ['Pizza'], expected: 1800)))['total_centavos'],
          1800);
      expect(
          (await store.command('misto', 'create',
              sale(ingredients: ['Misto'], expected: 2800)))['total_centavos'],
          2800);
      final water = await store.command('water', 'create', {
        'itens': [
          {
            'produto_nome': 'Água',
            'quantidade': 2,
            'preco_esperado_centavos': 350
          }
        ]
      });
      expect(water['total_centavos'], 700);
      expect((await store.priceCatalog())['rules'], priceChange(0)['rules']);
      expect(
          (await db.query('commands', where: 'id = ?', whereArgs: ['price']))
              .length,
          1);
    });
    test(
        'comanda desatualizada e cliente antigo são recusados sem criar pedido ou impressão',
        () async {
      await store.command('p', 'update_prices', priceChange(0));
      for (final payload in [sale(expected: 1200), sale()]) {
        await expectLater(
            store.command('stale', 'create', payload),
            throwsA(
                isA<BusinessError>().having((e) => e.status, 'status', 422)));
      }
      expect(await db.query('orders'), isEmpty);
      expect(await db.query('print_jobs'), isEmpty);
      expect(
          await db.query('meta', where: 'key LIKE ?', whereArgs: ['ticket:%']),
          isEmpty);
    });
    test('dois tablets: somente uma alteração de uma mesma revisão é aplicada',
        () async {
      final attempts = await Future.wait([
        for (final id in ['a', 'b'])
          store
              .command(id, 'update_prices', priceChange(0))
              .then<Object>((value) => value, onError: (Object error) => error)
      ]);
      expect(attempts.whereType<BusinessError>().single.status, 409);
      expect(attempts.whereType<Map>().length, 1);
    });
    test('backup e restauração preservam preços e regras no mesmo schema',
        () async {
      await store.command('price-backup', 'update_prices', priceChange(0));
      final contents = <String, dynamic>{};
      for (final table in BackupService.tables) {
        contents[table] = await db.query(table);
      }
      final key = BackupService.newKey();
      final bytes =
          await BackupService.encode({'schema': 1, 'tables': contents}, key);
      final restored = await databaseFactoryFfi.openDatabase(
          inMemoryDatabasePath,
          options: OpenDatabaseOptions(
              singleInstance: false,
              version: 1,
              onCreate: OrderStore.createSchema));
      try {
        final target = OrderStore(restored);
        await BackupService.restoreEmpty(target, bytes, key);
        expect(await target.priceCatalog(), await store.priceCatalog());
        expect(
            (await target.command('after-restore', 'create',
                sale(expected: 1400)))['total_centavos'],
            1400);
      } finally {
        await restored.close();
      }
    });
    test('valor inválido no lote reverte todos os produtos e a revisão',
        () async {
      final before = await store.priceCatalog();
      final bad = priceChange(0);
      (bad['products'] as List).add({'id': 8, 'preco_centavos': -1});
      await expectLater(store.command('bad', 'update_prices', bad),
          throwsA(isA<BusinessError>()));
      expect(await store.priceCatalog(), before);
      expect(await db.query('commands'), isEmpty);
    });
  });
  test('recusa definitiva de preço não prende confirmação pendente', () async {
    SharedPreferences.setMockInitialValues(
        {'address_v2': '127.0.0.1', 'secret_v2': 'test-secret-at-least-16'});
    await expectLater(RejectPriceApi().inserirPedido('pedidos', sale()),
        throwsA(isA<ApiException>()));
    expect(
        (await SharedPreferences.getInstance()).getString('pending_create_v2'),
        isNull);
  });

  for (final size in [
    const Size(768, 1024),
    const Size(1024, 768),
    const Size(360, 800)
  ]) {
    testWidgets(
        'edição de preços cabe em $size com fonte ampliada e salva após confirmação',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = PriceApi();
      await tester.pumpWidget(MaterialApp(
          theme: appTheme(),
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.3)),
              child: child!),
          home: ProductPricesScreen(api: api)));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('r:base_centavos')));
      await tester.enterText(
          find.byKey(const ValueKey('r:base_centavos')), '14,50');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salvar alterações'));
      await tester.pumpAndSettle();
      expect(api.saves, isEmpty);
      await tester.tap(find.text('Salvar preços'));
      await tester.pumpAndSettle();
      expect(api.saves.single['rules']['base_centavos'], 1450);
      expect(find.text('Preços salvos no servidor.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
      'edição inválida e conflito preservam valores digitados sem falso sucesso',
      (tester) async {
    final api = PriceApi()..conflict = true;
    await tester.pumpWidget(MaterialApp(home: ProductPricesScreen(api: api)));
    await tester.pumpAndSettle();
    final field = find.byKey(const ValueKey('r:base_centavos'));
    await tester.enterText(field, '-1');
    await tester.tap(find.text('Salvar alterações'));
    await tester.pumpAndSettle();
    expect(api.saves, isEmpty);
    await tester.enterText(field, '16,00');
    await tester.tap(find.text('Salvar alterações'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvar preços'));
    await tester.pumpAndSettle();
    expect(find.text('Preços salvos no servidor.'), findsNothing);
    expect(tester.widget<TextFormField>(field).controller!.text, '16,00');
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'mudança de preço pede nova conferência e envia o valor esperado correto',
      (tester) async {
    tester.view.physicalSize = const Size(768, 1024);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = PriceApi();
    final provider = PedidosProvider(api: api);
    addTearDown(provider.dispose);
    provider.adicionarItem(ItemPedido(
        id: 0,
        pedidoId: 0,
        numeroPedido: 0,
        quantidade: 1,
        produtoNome: 'Pastel',
        statusItem: 'aguardando',
        preco: 0,
        ingredientes: ['Carne'],
        observacoesItem: ''));
    await tester.pumpWidget(ChangeNotifierProvider.value(
        value: provider,
        child:
            MaterialApp(theme: appTheme(), home: NovoPedidoScreen(api: api))));
    await tester.pumpAndSettle();
    api.data = catalog(revision: 1, rules: const PricingRules(base: 1400));
    await tester.tap(find.text('Confirmar pedido'));
    await tester.pumpAndSettle();
    expect(api.orders, isEmpty);
    expect(
        find.text(
            'Preços atualizados. Confira o novo total e confirme novamente.'),
        findsOneWidget);
    await tester.tap(find.text('Confirmar pedido'));
    await tester.pumpAndSettle();
    expect(
        (api.orders.single['itens'] as List).single['preco_esperado_centavos'],
        1400);
    expect(tester.takeException(), isNull);
  });
}
