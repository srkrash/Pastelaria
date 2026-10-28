import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:pastelaria_app/providers/pedidos_provider.dart';
import 'package:pastelaria_app/screens/pastel_queue_screen.dart';
import 'package:pastelaria_app/services/api_service.dart';
import 'package:pastelaria_app/server/backup_service.dart';
import 'package:pastelaria_app/server/order_store.dart';
import 'package:pastelaria_app/ui/app_ui.dart';

Map<String, dynamic> item(int id,
        {int quantity = 5,
        int ready = 2,
        String type = 'pastel',
        String note = 'Sem cebola',
        List<String> ingredients = const ['Carne', 'Queijo']}) =>
    {
      'item_id': id,
      'produto_nome': type == 'pastel' ? 'Pastel' : 'Água',
      'produto_tipo': type,
      'quantidade': quantity,
      'quantidade_pronta': ready,
      'quantidade_entregue': ready > 0 ? 1 : 0,
      'quantidade_cancelada': 0,
      'ingredientes': ingredients,
      'observacoes_item': note,
    };
List<Map<String, dynamic>> fixture() => [
      {
        'pedido_id': 20,
        'numero_pedido': 1,
        'status': 'aberto',
        'revision': 1,
        'data_hora_pedido': '2026-10-28T20:01:00Z',
        'observacoes': '[Consumo]',
        'itens': [item(4)]
      },
      {
        'pedido_id': 10,
        'numero_pedido': 99,
        'status': 'aberto',
        'revision': 1,
        'data_hora_pedido': '2026-10-28T20:00:00Z',
        'observacoes': '[Viagem] Separar embalagem',
        'itens': [
          item(5,
              quantity: 2,
              ready: 0,
              note: 'Com cebola',
              ingredients: ['Carne']),
          item(4),
          item(2, quantity: 1, ready: 1),
          item(1, type: 'bebida')
        ]
      },
    ];

class KitchenApi extends ApiService {
  List<Map<String, dynamic>> orders = fixture();
  int revision = 1;
  bool failCommand = false, failSnapshot = false;
  final calls = <List<dynamic>>[];
  @override
  Future<Map<String, dynamic>> snapshot() async {
    if (failSnapshot) throw ApiException('Wi-Fi indisponível', 0);
    return jsonDecode(jsonEncode({'revision': revision, 'pedidos': orders}))
        as Map<String, dynamic>;
  }

  @override
  Future<void> changeQuantity(
      Map<String, dynamic> order, int itemId, int count, bool production,
      {String? commandId}) async {
    calls.add([order['pedido_id'], itemId, count, production]);
    if (failCommand) {
      throw ApiException('Pedido atualizado em outro tablet.', 409);
    }
    final current =
        orders.firstWhere((p) => p['pedido_id'] == order['pedido_id']);
    if (current['revision'] != order['revision']) {
      throw ApiException('Conflito', 409);
    }
    final i =
        (current['itens'] as List).firstWhere((i) => i['item_id'] == itemId);
    i['quantidade_pronta'] += count;
    current['revision']++;
    revision++;
  }
}

Future<PedidosProvider> mount(WidgetTester tester, KitchenApi api,
    {Size size = const Size(768, 1024),
    double scale = 1,
    GlobalKey? capture}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final provider = PedidosProvider(api: api);
  await provider.refresh();
  addTearDown(provider.dispose);
  await tester.pumpWidget(RepaintBoundary(
      key: capture,
      child: ChangeNotifierProvider.value(
          value: provider,
          child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: appTheme(
                  fontFamily: Platform.environment['KITCHEN_PREVIEW'] == null
                      ? null
                      : 'KitchenPreview'),
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!),
              home: PastelQueueScreen(api: api)))));
  await tester.pumpAndSettle();
  return provider;
}

void main() {
  setUpAll(() async {
    tz.initializeTimeZones();
    if (Platform.environment['KITCHEN_PREVIEW'] != null) {
      final font = FontLoader('KitchenPreview')
        ..addFont(File('C:/Windows/Fonts/segoeui.ttf')
            .readAsBytes()
            .then(ByteData.sublistView));
      await font.load();
      final icons = FontLoader('MaterialIcons')
        ..addFont(File(
                '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf')
            .readAsBytes()
            .then(ByteData.sublistView));
      await icons.load();
    }
  });
  for (final size in [
    const Size(1024, 650),
    const Size(768, 1024),
    const Size(360, 800)
  ]) {
    testWidgets('montagem destacada sem overflow em $size, fonte ampliada',
        (tester) async {
      final key = GlobalKey();
      await mount(tester, KitchenApi(), size: size, scale: 1.3, capture: key);
      expect(find.byKey(const ValueKey('next-10:4')), findsOneWidget);
      expect(find.text('MONTAR AGORA'), findsOneWidget);
      expect(find.text('ATENÇÃO AO PASTEL: Sem cebola'), findsOneWidget);
      expect(find.text('Água'), findsNothing);
      expect(find.text('Disponíveis: 1'), findsNothing);
      expect(tester.takeException(), isNull);
      if (size.width == 768 &&
          Platform.environment['KITCHEN_PREVIEW'] != null) {
        await tester.runAsync(() async {
          final image = await (key.currentContext!.findRenderObject()
                  as RenderRepaintBoundary)
              .toImage();
          final bytes =
              (await image.toByteData(format: ui.ImageByteFormat.png))!;
          await File(Platform.environment['KITCHEN_PREVIEW']!)
              .writeAsBytes(bytes.buffer.asUint8List());
          image.dispose();
        });
      }
    });
  }
  testWidgets(
      'saldo parcial permanece em destaque e conclusão avança por chegada e item',
      (tester) async {
    final api = KitchenApi();
    await mount(tester, api);
    Future<void> record({bool all = false}) async {
      final button =
          find.text(all ? 'Definir como pronto' : 'Informar quantidade');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      if (!all) {
        await tester.tap(find.text('Confirmar preparo'));
        await tester.pumpAndSettle();
      } else {
        expect(find.byType(AlertDialog), findsNothing);
      }
    }

    await record();
    expect(api.calls.single, [10, 4, 1, true]);
    expect(find.byKey(const ValueKey('next-10:4')), findsOneWidget);
    await record(all: true);
    expect(api.calls.last, [10, 4, 2, true]);
    expect(find.byKey(const ValueKey('next-10:5')), findsOneWidget);
    await record(all: true);
    expect(find.byKey(const ValueKey('next-20:4')), findsOneWidget);
    final first = api.orders.firstWhere((p) => p['pedido_id'] == 10);
    expect(
        (first['itens'] as List)
            .firstWhere((i) => i['item_id'] == 4)['quantidade_entregue'],
        1);
    expect(tester.takeException(), isNull);
  });
  testWidgets('pronto conclui todo o saldo do item em um toque sem diálogo',
      (tester) async {
    final api = KitchenApi();
    await mount(tester, api);
    final button = find.text('Definir como pronto');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(api.calls.single, [10, 4, 3, true]);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byKey(const ValueKey('next-10:5')), findsOneWidget);
    final items =
        api.orders.firstWhere((o) => o['pedido_id'] == 10)['itens'] as List;
    expect(items.firstWhere((i) => i['item_id'] == 4)['quantidade_pronta'], 5);
    expect(items.firstWhere((i) => i['item_id'] == 5)['quantidade_pronta'], 0);
    expect(
        items.firstWhere((i) => i['item_id'] == 4)['quantidade_entregue'], 1);
  });
  testWidgets('cozinha destaca o recheio adicional escrito na montagem',
      (tester) async {
    final api = KitchenApi();
    final current = api.orders.firstWhere((o) => o['pedido_id'] == 10);
    (current['itens'] as List)
        .firstWhere((i) => i['item_id'] == 4)['adicionais'] = [
      {'nome': 'Queijo extra', 'preco_centavos': 300},
    ];
    await mount(tester, api, scale: 1.3);
    expect(
        find.text('Carne + Queijo + adicional: Queijo extra'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('conflito não avança e falha de conexão desabilita registro',
      (tester) async {
    final api = KitchenApi()..failCommand = true;
    final provider = await mount(tester, api);
    await tester.ensureVisible(find.text('Definir como pronto'));
    await tester.tap(find.text('Definir como pronto'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('next-10:4')), findsOneWidget);
    expect(find.text('Pedido atualizado em outro tablet.'), findsOneWidget);
    api.failSnapshot = true;
    await provider.refresh();
    await tester.pumpAndSettle();
    final action = tester.widget<FilledButton>(
        find.byWidgetPredicate((widget) => widget is FilledButton).first);
    expect(action.onPressed, isNull);
    expect(api.calls.length, 1);
    expect(tester.takeException(), isNull);
  });
  test('backup pré-atualização autenticado e restaurável em cópia em memória',
      () async {
    final folder = Directory(Platform.environment['TABLET_BACKUP_DIR']!);
    final key =
        await File('${folder.path}/chave-backups-servidor.txt').readAsString();
    final backupName = Platform.environment['TABLET_BACKUP_NAME'] ??
        'antes-bi-cozinha.pastelbackup';
    final bytes = await File('${folder.path}/$backupName').readAsBytes();
    final decoded = await BackupService.decode(bytes, key);
    final tables = decoded['tables'] as Map;
    expect((tables['orders'] as List).length, greaterThanOrEqualTo(9862));
    expect((tables['products'] as List).length, 50);
    sqfliteFfiInit();
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath,
        options:
            OpenDatabaseOptions(version: 1, onCreate: OrderStore.createSchema));
    try {
      await BackupService.restoreEmpty(OrderStore(db), bytes, key);
      expect(
          (await db.query('orders')).length, (tables['orders'] as List).length);
    } finally {
      await db.close();
    }
  },
      skip: Platform.environment['TABLET_BACKUP_DIR'] == null
          ? 'Private local backup only.'
          : false);
}
