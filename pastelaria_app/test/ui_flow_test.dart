import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pastelaria_app/models/item_pedido.dart';
import 'package:pastelaria_app/providers/pedidos_provider.dart';
import 'package:pastelaria_app/services/api_service.dart';
import 'package:pastelaria_app/screens/add_pastel_screen.dart';
import 'package:pastelaria_app/screens/add_product_screen.dart';
import 'package:pastelaria_app/screens/novo_pedido_screen.dart';
import 'package:pastelaria_app/screens/main_screen.dart';
import 'package:pastelaria_app/screens/order_queue_screen.dart';
import 'package:pastelaria_app/screens/editar_pedido_selecionado.dart';
import 'package:pastelaria_app/ui/app_ui.dart';

class UiApi extends ApiService {
  @override
  Future<Map<String, dynamic>> getPriceCatalog() async => {
        'catalog_revision': 0,
        'rules': {
          'base_centavos': 1200,
          'adicional_centavos': 300,
          'pizza_centavos': 1500,
          'misto_centavos': 2500
        },
        'products': await getProdutos(),
      };
  final List<dynamic> orders;
  Map<String, dynamic>? sent;
  int cancelled = 0;
  UiApi({this.orders = const []});
  @override
  Future<Map<String, dynamic>> snapshot() async =>
      {'revision': 1, 'pedidos': orders};
  @override
  Future<Map<String, dynamic>> getPedidoPorId(int id) async => {
        'id': id,
        'pedido_id': id,
        'numero_pedido': 14,
        'status': 'aberto',
        'total_centavos': 2400,
        'observacoes': '[Viagem]',
        'itens': [
          {
            'produto_nome': 'Pastel',
            'quantidade': 2,
            'subtotal': 24.0,
            'ingredientes': ['Carne', 'Queijo'],
            'observacoes_item': '',
            'quantidade_pronta': 0,
            'quantidade_entregue': 0,
            'quantidade_cancelada': 0
          }
        ],
      };
  @override
  Future<bool> updatePedidoStatus(int id, String status) async {
    cancelled++;
    return true;
  }

  @override
  Future<List<dynamic>> getProdutos({String? tipo}) async => [
        {'id': 1, 'nome': 'Água sem gás', 'preco_centavos': 200},
        {'id': 2, 'nome': 'Coca-Cola lata', 'preco_centavos': 600},
        {'id': 3, 'nome': 'Suco natural 500ml', 'preco_centavos': 500},
      ];
  @override
  Future<Map<String, dynamic>> inserirPedido(
      String endpoint, Map<String, dynamic> data) async {
    sent = data;
    return {'numero_pedido': 14, 'total_pedido': 30.0};
  }
}

ItemPedido draftItem({String name = 'Pastel'}) => ItemPedido(
    id: 1,
    pedidoId: 0,
    numeroPedido: 0,
    quantidade: 2,
    produtoNome: name,
    statusItem: 'aguardando',
    preco: 12,
    ingredientes: name == 'Pastel' ? ['Carne', 'Queijo'] : [],
    observacoesItem: 'Bem passado');
final _captureKey = GlobalKey();
Future<void> mount(WidgetTester tester, Widget page, PedidosProvider provider,
    {Size size = const Size(1024, 768), double scale = 1}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(ChangeNotifierProvider.value(
      value: provider,
      child: RepaintBoundary(
          key: _captureKey,
          child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: appTheme(
                  fontFamily: Platform.environment['UI_PREVIEW'] == '1'
                      ? 'Preview'
                      : null),
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!),
              home: page))));
  await tester.pumpAndSettle();
}

Future<void> preview(WidgetTester tester, String name) async {
  if (Platform.environment['UI_PREVIEW'] != '1') return;
  await tester.runAsync(() async {
    final boundary = _captureKey.currentContext!.findRenderObject()!
        as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final dir = Directory('../tools/ui-previews');
    await dir.create(recursive: true);
    await File('${dir.path}/$name.png')
        .writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(() async {
    if (Platform.environment['UI_PREVIEW'] != '1') return;
    TestWidgetsFlutterBinding.ensureInitialized();
    final font = FontLoader('Preview')
      ..addFont(File('C:/Windows/Fonts/segoeui.ttf')
          .readAsBytes()
          .then(ByteData.sublistView));
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(File(
              'D:/Dev/Flutter/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf')
          .readAsBytes()
          .then(ByteData.sublistView));
    await icons.load();
  });
  setUp(() => SharedPreferences.setMockInitialValues(
      {'address_v2': '192.168.1.10', 'secret_v2': 'test-key-1234567890'}));
  testWidgets('pastel exige recheio e mostra preço e quantidade em tempo real',
      (tester) async {
    final p = PedidosProvider(api: UiApi());
    addTearDown(p.dispose);
    await mount(tester, const AddPastelScreen(), p);
    expect(
        tester
            .widget<FilledButton>(find
                .ancestor(
                    of: find.text('Adicionar 1 pastel'),
                    matching: find.byWidgetPredicate((w) => w is FilledButton))
                .first)
            .onPressed,
        isNull);
    await tester.tap(find.text('Carne'));
    await tester.tap(find.text('Queijo'));
    await tester.tap(find.text('Bacon'));
    await tester.pumpAndSettle();
    expect(find.text('${money(1500)} por pastel'), findsOneWidget);
    await tester.tap(find.byTooltip('Aumentar Quantidade'));
    await tester.pumpAndSettle();
    expect(find.text('Adicionar 2 pastéis'), findsOneWidget);
    expect(find.text(money(3000)), findsOneWidget);
    await preview(tester, 'recheios');
    expect(tester.takeException(), isNull);
  });
  testWidgets('pastel cabe em retrato com fonte ampliada e teclado',
      (tester) async {
    final p = PedidosProvider(api: UiApi());
    addTearDown(p.dispose);
    await mount(tester, const AddPastelScreen(), p,
        size: const Size(600, 960), scale: 1.3);
    expect(tester.takeException(), isNull);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('busca sem acentos mantém produtos selecionados fora do filtro',
      (tester) async {
    final p = PedidosProvider(api: UiApi());
    addTearDown(p.dispose);
    await mount(
        tester, AddProductScreen(productType: 'bebida', api: UiApi()), p);
    await tester.enterText(find.byType(TextField), 'agua');
    await tester.pumpAndSettle();
    expect(find.text('Água sem gás'), findsOneWidget);
    expect(find.text('Coca-Cola lata'), findsNothing);
    await tester.tap(find.byTooltip('Aumentar Água sem gás'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'coca');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Aumentar Coca-Cola lata'));
    await tester.pumpAndSettle();
    expect(find.text('2 unidades selecionadas'), findsOneWidget);
    expect(find.text(money(800)), findsOneWidget);
    await tester.enterText(find.byType(TextField), '');
    await tester.pumpAndSettle();
    await preview(tester, 'bebidas');
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'comanda ajusta quantidade e desfaz remoção sem perder observações',
      (tester) async {
    final p = PedidosProvider(api: UiApi());
    p.adicionarItem(draftItem());
    p.draftNotes = 'Separar embalagens';
    addTearDown(p.dispose);
    await mount(tester, NovoPedidoScreen(api: UiApi()), p);
    expect(find.text(money(2400)), findsWidgets);
    await tester.tap(find.byTooltip('Aumentar Pastel'));
    await tester.pumpAndSettle();
    expect(p.itensPedidoAtual.single.quantidade, 3);
    expect(find.text(money(3600)), findsWidgets);
    await preview(tester, 'comanda');
    await tester.tap(find.byTooltip('Remover Pastel'));
    await tester.pumpAndSettle();
    expect(p.itensPedidoAtual, isEmpty);
    await tester.tap(find.text('Desfazer'));
    await tester.pumpAndSettle();
    expect(p.itensPedidoAtual.single.quantidade, 3);
    expect(p.draftNotes, 'Separar embalagens');
    expect(tester.takeException(), isNull);
  });
  testWidgets('comanda em retrato com teclado não transborda', (tester) async {
    final p = PedidosProvider(api: UiApi());
    p.adicionarItem(draftItem());
    addTearDown(p.dispose);
    await mount(tester, NovoPedidoScreen(api: UiApi()), p,
        size: const Size(600, 960), scale: 1.3);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('navegação mostra só um cabeçalho e permite trocar papéis',
      (tester) async {
    final p = PedidosProvider(api: UiApi());
    await p.refresh();
    addTearDown(p.dispose);
    await mount(tester, const MainScreen(), p);
    expect(find.byType(AppBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsOneWidget);
    await tester.tap(find.text('Cozinha'));
    await tester.pumpAndSettle();
    expect(find.text('Produção de pastéis'), findsOneWidget);
    expect(find.byType(AppBar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'fila permite buscar e limpar filtro sem ocultar pedidos involuntariamente',
      (tester) async {
    final api = UiApi(orders: [
      {
        'pedido_id': 14,
        'numero_pedido': 14,
        'status': 'aberto',
        'revision': 1,
        'data_hora_pedido': DateTime.now()
            .subtract(const Duration(minutes: 12))
            .toUtc()
            .toIso8601String(),
        'observacoes': '[Viagem] Separar bebidas',
        'itens': [
          {
            'item_id': 1,
            'produto_nome': 'Pastel',
            'produto_tipo': 'pastel',
            'quantidade': 5,
            'quantidade_pronta': 2,
            'quantidade_entregue': 1,
            'quantidade_cancelada': 0,
            'ingredientes': ['Carne', 'Queijo'],
            'observacoes_item': 'Bem passado'
          }
        ]
      },
      {
        'pedido_id': 15,
        'numero_pedido': 15,
        'status': 'aberto',
        'revision': 2,
        'data_hora_pedido': DateTime.now()
            .subtract(const Duration(minutes: 7))
            .toUtc()
            .toIso8601String(),
        'observacoes': '[Consumo]',
        'itens': [
          {
            'item_id': 1,
            'produto_nome': 'Pastel',
            'produto_tipo': 'pastel',
            'quantidade': 2,
            'quantidade_pronta': 0,
            'quantidade_entregue': 0,
            'quantidade_cancelada': 0,
            'ingredientes': ['Frango', 'Catupiry'],
            'observacoes_item': ''
          }
        ]
      },
    ]);
    final p = PedidosProvider(api: api);
    await p.refresh();
    addTearDown(p.dispose);
    await mount(tester, const OrderQueueScreen(production: false), p);
    await preview(tester, 'entrega');
    await tester.tap(find.text('Disponíveis (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Senha 14'), findsOneWidget);
    expect(find.text('Senha 15'), findsNothing);
    await tester.enterText(find.byType(TextField), '99');
    await tester.pumpAndSettle();
    expect(find.text('Nenhum pedido neste filtro.'), findsOneWidget);
    await tester.tap(find.text('Mostrar todos os pedidos'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty);
    expect(find.text('Senha 14'), findsOneWidget);
    expect(find.text('Senha 15'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('produtos em retrato com fonte ampliada não transbordam',
      (tester) async {
    final p = PedidosProvider(api: UiApi());
    addTearDown(p.dispose);
    await mount(
        tester, AddProductScreen(productType: 'bebida', api: UiApi()), p,
        size: const Size(600, 960), scale: 1.3);
    expect(tester.takeException(), isNull);
  });
  testWidgets('confirmação envia tipo e observações selecionados na comanda',
      (tester) async {
    final api = UiApi();
    final p = PedidosProvider(api: api);
    p.adicionarItem(draftItem());
    addTearDown(p.dispose);
    await mount(
        tester,
        Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => NovoPedidoScreen(api: api))),
                    child: const Text('Abrir comanda')))),
        p);
    await tester.tap(find.text('Abrir comanda'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Viagem'));
    await tester.enterText(find.byType(TextField), 'Separar bebidas');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar pedido'));
    await tester.pumpAndSettle();
    expect(api.sent!['observacoes_pedido'], '[Viagem] Separar bebidas');
    expect((api.sent!['itens'] as List).single['quantidade'], 2);
    expect(p.itensPedidoAtual, isEmpty);
    expect(p.ultimoPedidoConfirmado!['numero'], 14);
    expect(tester.takeException(), isNull);
  });
  testWidgets('cancelamento exige confirmação e Voltar não altera pedido',
      (tester) async {
    final api = UiApi();
    final p = PedidosProvider(api: api);
    addTearDown(p.dispose);
    await mount(
        tester, EditarPedidoSelecionadoScreen(pedidoId: 1, api: api), p);
    await tester.tap(find.text('Cancelar pedido'));
    await tester.pumpAndSettle();
    expect(find.text('Cancelar este pedido?'), findsOneWidget);
    expect(api.cancelled, 0);
    await tester.tap(find.text('Voltar'));
    await tester.pumpAndSettle();
    expect(api.cancelled, 0);
    expect(find.text('Senha 14'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
