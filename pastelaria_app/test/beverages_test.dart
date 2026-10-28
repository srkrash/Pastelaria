import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pastelaria_app/models/beverage_catalog.dart';
import 'package:pastelaria_app/models/item_pedido.dart';
import 'package:pastelaria_app/screens/add_product_screen.dart';
import 'package:pastelaria_app/services/api_service.dart';
import 'package:pastelaria_app/ui/app_ui.dart';

List<Map<String, dynamic>> drinks() => [
      {'id': 1, 'nome': 'Coca-Cola Lata', 'preco_centavos': 600},
      {'id': 2, 'nome': 'Coca-Cola Zero Lata', 'preco_centavos': 600},
      {'id': 3, 'nome': 'Skol Lata', 'preco_centavos': 500},
      {'id': 4, 'nome': 'Coca-cola 600ml', 'preco_centavos': 900},
      {'id': 5, 'nome': 'Coca-cola 1L', 'preco_centavos': 1100},
      {'id': 6, 'nome': 'Coca-cola 2L', 'preco_centavos': 1500},
      {'id': 7, 'nome': 'Água sem gás 500ml', 'preco_centavos': 200},
      {'id': 8, 'nome': 'Suco Natural 300ml', 'preco_centavos': 600},
      {'id': 9, 'nome': 'Mineirinho 200ml', 'preco_centavos': 300},
      {'id': 10, 'nome': 'Mineirinho 250ml', 'preco_centavos': 400},
      {
        'id': 11,
        'nome': 'Energético Extra Power 473ml',
        'preco_centavos': 1200
      },
    ];

class DrinksApi extends ApiService {
  final List<dynamic> data;
  DrinksApi({List<dynamic>? data}) : data = data ?? drinks();
  @override
  Future<List<dynamic>> getProdutos({String? tipo}) async => data;
}

final capture = GlobalKey();
Future<void> preview(String name) async {
  final path = Platform.environment['BEVERAGE_PREVIEW_DIR'];
  if (path == null) return;
  final boundary =
      capture.currentContext!.findRenderObject() as RenderRepaintBoundary;
  final image = await boundary.toImage();
  final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
  await Directory(path).create(recursive: true);
  await File('$path/$name.png').writeAsBytes(bytes.buffer.asUint8List());
  image.dispose();
}

void main() {
  setUpAll(() async {
    if (Platform.environment['BEVERAGE_PREVIEW_DIR'] == null) return;
    final font = FontLoader('BeveragePreview')
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
  });
  test('marca e volume separam cerveja de refrigerante e preservam variantes',
      () {
    final cases = {
      'Coca-Cola Lata': BeverageCategory.cans,
      'Guaraná Antarctica Lata': BeverageCategory.cans,
      'Antarctica Lata': BeverageCategory.beer,
      'Heineken Lata': BeverageCategory.beer,
      'Coca-cola 600 ml': BeverageCategory.soda600,
      'Coca-cola zero 1L': BeverageCategory.soda1l,
      'Mineiro 2 litros': BeverageCategory.soda2l,
      'Mineirinho 200ml': BeverageCategory.small,
      'Mineirinho 250ml': BeverageCategory.small,
      'Água com gás 500ml': BeverageCategory.water,
      'Suco Natural 500ml': BeverageCategory.juice,
      'Energético Extra Power 473ml': BeverageCategory.energy,
      'Kombucha nova': BeverageCategory.other,
    };
    for (final entry in cases.entries) {
      expect(BeverageCatalog.category(entry.key), entry.value,
          reason: entry.key);
    }
    expect(BeverageCatalog.image('Coca-Cola Zero Lata'),
        'assets/bebidas/coca_zero_lata.jpg');
    expect(BeverageCatalog.image('Mineirinho 200ml'),
        'assets/bebidas/mineiro_200.png');
    expect(BeverageCatalog.image('Água Mineiro 250ml'), isNull);
  });
  test(
      'catálogo original inteiro tem categoria e as 21 fotos estão no bundle offline',
      () async {
    final catalog =
        jsonDecode(await rootBundle.loadString('assets/catalogo.json')) as List;
    final names = [
      ...catalog
          .where((p) => p['tipo'] == 'bebida')
          .map((p) => p['nome'] as String),
      'Mineirinho 200ml',
      'Mineirinho 250ml'
    ];
    for (final name in names) {
      expect(BeverageCatalog.category(name), isNot(BeverageCategory.other),
          reason: name);
      final asset = BeverageCatalog.image(name);
      if (asset != null) {
        expect((await rootBundle.load(asset)).lengthInBytes, greaterThan(1000));
      }
    }
    final sources =
        jsonDecode(await rootBundle.loadString('assets/bebidas/sources.json'))
            as Map;
    expect((sources['images'] as List).length, 21);
    for (final source in sources['images'] as List) {
      final bytes = await rootBundle.load(source['asset'] as String);
      expect(
          sha256
              .convert(bytes.buffer
                  .asUint8List(bytes.offsetInBytes, bytes.lengthInBytes))
              .toString(),
          source['sha256']);
    }
  });
  for (final size in [
    const Size(768, 1024),
    const Size(1024, 768),
    const Size(360, 800)
  ]) {
    testWidgets('categorias e fotos cabem em $size, fonte ampliada e teclado',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(RepaintBoundary(
          key: capture,
          child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: appTheme(
                  fontFamily:
                      Platform.environment['BEVERAGE_PREVIEW_DIR'] == null
                          ? null
                          : 'BeveragePreview'),
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: const TextScaler.linear(1.3)),
                  child: child!),
              home:
                  AddProductScreen(productType: 'bebida', api: DrinksApi()))));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('category-cans')), findsOneWidget);
      expect(find.text('Coca-Cola Lata'), findsNothing);
      if (size.width == 768) {
        await tester.runAsync(() => preview('bebidas-categorias'));
      }
      await tester.tap(find.byKey(const ValueKey('category-cans')));
      await tester.pumpAndSettle();
      expect(find.text('Coca-Cola Lata'), findsOneWidget);
      expect(find.text('Skol Lata'), findsNothing);
      final images = tester.widgetList<Image>(find.byType(Image)).toList();
      await tester.runAsync(() async {
        await Future.wait(images.map(
            (photo) => precacheImage(photo.image, capture.currentContext!)));
      });
      await tester.pumpAndSettle();
      expect(
          tester
              .widgetList<RawImage>(find.byType(RawImage))
              .where((image) => image.image != null)
              .length,
          2);
      for (final photo in tester.widgetList<Image>(find.byType(Image))) {
        final provider = photo.image is ResizeImage
            ? (photo.image as ResizeImage).imageProvider
            : photo.image;
        expect(provider, isA<AssetImage>());
      }
      expect(tester.takeException(), isNull);
      if (size.width == 768) {
        await tester.runAsync(() => preview('bebidas-latas'));
      }
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      addTearDown(tester.view.resetViewInsets);
      await tester.enterText(find.byType(TextField), 'coca cola');
      await tester.pumpAndSettle();
      expect(find.text('Busca em todas as bebidas'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
      'trocar categoria e buscar preserva seleção e devolve cada ID uma vez',
      (tester) async {
    tester.view.physicalSize = const Size(768, 1024);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    List<ItemPedido>? result;
    await tester.pumpWidget(MaterialApp(
        theme: appTheme(),
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () async {
                      result = await Navigator.push<List<ItemPedido>>(
                          context,
                          MaterialPageRoute(
                              builder: (_) => AddProductScreen(
                                  productType: 'bebida', api: DrinksApi())));
                    },
                    child: const Text('Abrir bebidas'))))));
    await tester.tap(find.text('Abrir bebidas'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('category-cans')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Aumentar Coca-Cola Lata'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Categorias'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('category-beer')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Aumentar Skol Lata'));
    await tester.pump();
    await tester.tap(find.byTooltip('Aumentar Skol Lata'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'agua');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Aumentar Água sem gás 500ml'));
    await tester.pumpAndSettle();
    expect(find.text('4 unidades selecionadas'), findsOneWidget);
    expect(find.text(money(1800)), findsOneWidget);
    await tester.tap(find.byTooltip('Limpar busca'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ver selecionados (4)'));
    await tester.pumpAndSettle();
    expect(find.text('Coca-Cola Zero Lata'), findsNothing);
    await tester.tap(find.text('Adicionar ao pedido'));
    await tester.pumpAndSettle();
    expect(result!.map((i) => i.id), [1, 3, 7]);
    expect(result!.map((i) => i.quantidade), [1, 2, 1]);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'produto novo aparece em Outras bebidas e catálogo vazio é explícito',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: AddProductScreen(
            productType: 'bebida',
            api: DrinksApi(data: [
              {'id': 99, 'nome': 'Kombucha nova', 'preco_centavos': 500}
            ]))));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('category-other')));
    await tester.pumpAndSettle();
    expect(find.text('Kombucha nova'), findsOneWidget);
    await tester.pumpWidget(MaterialApp(
        home: AddProductScreen(
            key: const ValueKey('empty'),
            productType: 'bebida',
            api: DrinksApi(data: []))));
    await tester.pumpAndSettle();
    expect(find.text('Nenhum produto encontrado.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
