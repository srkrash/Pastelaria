import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:pastelaria_app/models/item_pedido.dart';
import 'package:pastelaria_app/models/pastel_extra.dart';
import 'package:pastelaria_app/models/pricing_rules.dart';
import 'package:pastelaria_app/providers/pedidos_provider.dart';
import 'package:pastelaria_app/screens/add_pastel_screen.dart';
import 'package:pastelaria_app/screens/novo_pedido_screen.dart';
import 'package:pastelaria_app/server/order_store.dart';
import 'package:pastelaria_app/server/receipt_encoder.dart';
import 'package:pastelaria_app/server/bi_service.dart';
import 'package:pastelaria_app/server/backup_service.dart';
import 'package:pastelaria_app/services/api_service.dart';
import 'package:pastelaria_app/ui/app_ui.dart';

Map<String, dynamic> sale(
        {int expected = 1550,
        dynamic extras = const [
          {'nome': 'Camarão', 'preco_centavos': 350},
        ]}) =>
    {
      'itens': [
        {
          'produto_nome': 'Pastel',
          'quantidade': 2,
          'ingredientes': ['Carne'],
          'preco_esperado_centavos': expected,
          'adicionais': extras,
        }
      ]
    };

class ExtraApi extends ApiService {
  Map<String, dynamic>? sent;
  @override
  Future<Map<String, dynamic>> getPriceCatalog() async => {
        'catalog_revision': 0,
        'rules': const PricingRules().toJson(),
        'products': [],
      };
  @override
  Future<Map<String, dynamic>> snapshot() async =>
      {'revision': 1, 'pedidos': []};
  @override
  Future<Map<String, dynamic>> inserirPedido(
      String endpoint, Map<String, dynamic> payload) async {
    sent = payload;
    return {'numero_pedido': 1, 'total_pedido': 31.0};
  }
}

Future<void> mount(WidgetTester tester, Widget child,
    {Size size = const Size(768, 1024)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(
      theme: appTheme(),
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.3)),
          child: child!),
      home: child));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    tz.initializeTimeZones();
  });
  group('adicionais no servidor', () {
    late Database db;
    late OrderStore store;
    setUp(() async {
      db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath,
          options: OpenDatabaseOptions(
              version: 1, onCreate: OrderStore.createSchema));
      store = OrderStore(db, now: () => DateTime.utc(2026, 10, 28, 18));
      await store.seed([
        {'nome': 'Pastel', 'tipo': 'pastel', 'preco_centavos': 0},
        {'nome': 'Carne', 'tipo': 'ingrediente', 'preco_centavos': 0},
        {'nome': 'Queijo', 'tipo': 'ingrediente', 'preco_centavos': 0},
        {'nome': 'Pizza', 'tipo': 'ingrediente', 'preco_centavos': 1500},
        {'nome': 'Água', 'tipo': 'bebida', 'preco_centavos': 200},
      ]);
    });
    tearDown(() => db.close());
    test('cobra por unidade, preserva adicional e reenvio não duplica',
        () async {
      final order = await store.command('extra-sale', 'create', sale());
      expect(order['total_centavos'], 3100);
      final item = order['itens'][0];
      expect(item['preco_base_unitario_centavos'], 1200);
      expect(item['preco_unitario_centavos'], 1550);
      expect(item['adicionais'], [
        {'nome': 'Camarão', 'preco_centavos': 350}
      ]);
      expect(await store.command('extra-sale', 'create', sale()), order);
      expect(await db.query('orders'), hasLength(1));
      expect(await db.query('print_jobs'), hasLength(1));
      expect(ascii.decode(encodeReceipt(order)),
          contains('ADICIONAL: Camarao (+R\$ 3,50 por pastel)'));
      final report = await BiService(store).report('2026-10-28', '2026-10-28');
      expect(report['current']['value_centavos'], 3100);
      expect(report['current']['flavors'].single['label'], contains('Camarão'));
      expect(ItemPedido.fromJson(item).adicionais.single.cents, 350);
    });
    test(
        'rejeita valor fracionado, negativo, nome vazio, controles e total divergente sem salvar',
        () async {
      var index = 0;
      for (final raw in [
        [
          {'nome': 'Extra', 'preco_centavos': 3.5}
        ],
        [
          {'nome': 'Extra', 'preco_centavos': -1}
        ],
        [
          {'nome': 'Extra', 'preco_centavos': 1000000}
        ],
        [
          {'nome': '  ', 'preco_centavos': 300}
        ],
        [
          {'nome': 'Extra\x1b@', 'preco_centavos': 300}
        ],
        [
          {'nome': 'Extra', 'preco_centavos': '300'}
        ],
        'Extra',
      ]) {
        await expectLater(
            store.command('invalid-${index++}', 'create', sale(extras: raw)),
            throwsA(isA<BusinessError>()));
      }
      await expectLater(
          store.command('wrong-total', 'create', sale(expected: 1200)),
          throwsA(isA<BusinessError>().having((e) => e.status, 'status', 422)));
      final missing = sale();
      (missing['itens'] as List).first.remove('preco_esperado_centavos');
      await expectLater(store.command('missing-total', 'create', missing),
          throwsA(isA<BusinessError>()));
      final beverage = sale();
      beverage['itens'][0]['produto_nome'] = 'Água';
      await expectLater(store.command('beverage-extra', 'create', beverage),
          throwsA(isA<BusinessError>()));
      expect(await db.query('orders'), isEmpty);
      expect(await db.query('print_jobs'), isEmpty);
    });
    test(
        'mudança no cadastro não altera o adicional cotado nem histórico; backup preserva dados',
        () async {
      final before = await store.command('before', 'create', sale());
      await store.command('change', 'update_prices', {
        'expected_catalog_revision': 0,
        'rules': const PricingRules(base: 1400, extra: 500).toJson(),
        'products': [
          {'id': 5, 'preco_centavos': 300}
        ],
      });
      expect(await store.order(before['id']), before);
      await expectLater(store.command('old-price', 'create', sale()),
          throwsA(isA<BusinessError>()));
      final next =
          await store.command('new-price', 'create', sale(expected: 1750));
      expect(next['total_centavos'], 3500);
      expect(next['itens'][0]['adicionais'][0]['preco_centavos'], 350);
      final tables = <String, dynamic>{};
      for (final table in BackupService.tables) {
        tables[table] = await db.query(table);
      }
      final key = BackupService.newKey();
      final bytes =
          await BackupService.encode({'schema': 1, 'tables': tables}, key);
      final restored = await databaseFactoryFfi.openDatabase(
          inMemoryDatabasePath,
          options: OpenDatabaseOptions(
              version: 1,
              singleInstance: false,
              onCreate: OrderStore.createSchema));
      try {
        final target = OrderStore(restored);
        await BackupService.restoreEmpty(target, bytes, key);
        expect(await target.order(before['id']), before);
      } finally {
        await restored.close();
      }
    });
    test(
        'Pizza e vários adicionais usam preço especial sem contar como recheios comuns',
        () async {
      final payload = sale(expected: 2000, extras: [
        {'nome': 'Queijo extra', 'preco_centavos': 300},
        {'nome': 'Molho', 'preco_centavos': 200},
      ]);
      payload['itens'][0]['ingredientes'] = ['Pizza'];
      expect(
          (await store.command(
              'pizza-extras', 'create', payload))['total_centavos'],
          4000);
    });
  });
  for (final size in [const Size(768, 1024), const Size(1024, 768)]) {
    testWidgets(
        'valor padrão do cadastro, cobrança por pastel e retorno da montagem em $size',
        (tester) async {
      Map<String, dynamic>? result;
      await mount(
          tester,
          Builder(
              builder: (context) => TextButton(
                  onPressed: () async {
                    result = await Navigator.push<Map<String, dynamic>>(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const AddPastelScreen(
                                pricing: PricingRules(extra: 450))));
                  },
                  child: const Text('Abrir'))),
          size: size);
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Carne'));
      await tester.tap(find.byTooltip('Aumentar Quantidade'));
      final extra = find.text('Recheio adicional');
      await tester.ensureVisible(extra);
      await tester.tap(extra);
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<TextFormField>(find.byKey(const ValueKey('extra-price')))
              .controller!
              .text,
          '4,50');
      await tester.enterText(
          find.byKey(const ValueKey('extra-name')), 'Camarão');
      await tester.tap(find.text('Adicionar recheio'));
      await tester.pumpAndSettle();
      expect(find.text('${money(1650)} por pastel'), findsOneWidget);
      expect(find.text(money(3300)), findsOneWidget);
      await tester.tap(find.text('Adicionar 2 pastéis'));
      await tester.pumpAndSettle();
      expect(result!['adicionais'], [
        {'nome': 'Camarão', 'preco_centavos': 450}
      ]);
      expect(result!['quantidade'], 2);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
      'valor pode ser ajustado e adicional removido; entrada inválida não fecha diálogo',
      (tester) async {
    await mount(tester, const AddPastelScreen());
    await tester.tap(find.text('Carne'));
    await tester.ensureVisible(find.text('Recheio adicional'));
    await tester.tap(find.text('Recheio adicional'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Adicionar recheio'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.enterText(
        find.byKey(const ValueKey('extra-name')), 'Queijo extra');
    await tester.enterText(find.byKey(const ValueKey('extra-price')), '2,75');
    await tester.tap(find.text('Adicionar recheio'));
    await tester.pumpAndSettle();
    expect(find.text('${money(1475)} por pastel'), findsOneWidget);
    await tester.tap(find.byTooltip('Remover adicional Queijo extra'));
    await tester.pumpAndSettle();
    expect(find.text('${money(1200)} por pastel'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'comanda envia nome e centavos do adicional com preço unitário recalculado',
      (tester) async {
    final api = ExtraApi();
    final provider = PedidosProvider(api: api);
    addTearDown(provider.dispose);
    provider.adicionarItem(ItemPedido(
        id: 0,
        pedidoId: 0,
        numeroPedido: 0,
        quantidade: 2,
        produtoNome: 'Pastel',
        statusItem: 'aguardando',
        preco: 0,
        ingredientes: ['Carne'],
        observacoesItem: '',
        adicionais: const [PastelExtra(name: 'Camarão', cents: 350)]));
    await mount(
        tester,
        ChangeNotifierProvider.value(
            value: provider, child: NovoPedidoScreen(api: api)));
    expect(find.textContaining('Adicional: Camarão'), findsOneWidget);
    await tester.tap(find.text('Confirmar pedido'));
    await tester.pumpAndSettle();
    expect(api.sent!['itens'][0]['adicionais'], [
      {'nome': 'Camarão', 'preco_centavos': 350}
    ]);
    expect(api.sent!['itens'][0]['preco_esperado_centavos'], 1550);
    expect(provider.itensPedidoAtual, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
