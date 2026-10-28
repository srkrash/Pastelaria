import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pastelaria_app/providers/pedidos_provider.dart';
import 'package:pastelaria_app/screens/order_queue_screen.dart';
import 'package:pastelaria_app/services/api_service.dart';
import 'package:pastelaria_app/ui/app_ui.dart';

Map<String, dynamic> order(int id, {int ready = 4}) => {
      'pedido_id': id,
      'numero_pedido': id,
      'status': 'aberto',
      'revision': 1,
      'data_hora_pedido': '2026-10-28T18:00:00Z',
      'observacoes': '[Viagem]',
      'itens': [
        {
          'item_id': 1,
          'produto_nome': 'Pastel',
          'produto_tipo': 'pastel',
          'quantidade': 5,
          'quantidade_pronta': ready,
          'quantidade_entregue': 1,
          'quantidade_cancelada': 0,
          'ingredientes': ['Carne'],
          'observacoes_item': ''
        },
        {
          'item_id': 2,
          'produto_nome': 'Água',
          'produto_tipo': 'bebida',
          'quantidade': 2,
          'quantidade_pronta': 2,
          'quantidade_entregue': 1,
          'quantidade_cancelada': 0,
          'ingredientes': [],
          'observacoes_item': ''
        },
      ],
    };

class DeliveryApi extends ApiService {
  final orders = [order(1), order(2, ready: 5)];
  int revision = 1;
  final calls = <int>[];
  Completer<void>? gate;
  bool fail = false;
  @override
  Future<Map<String, dynamic>> snapshot() async =>
      jsonDecode(jsonEncode({'revision': revision, 'pedidos': orders}))
          as Map<String, dynamic>;
  @override
  Future<void> deliverOrder(Map<String, dynamic> captured,
      {String? commandId}) async {
    calls.add(captured['pedido_id'] as int);
    if (gate != null) await gate!.future;
    if (fail) throw ApiException('Pedido atualizado em outro tablet.', 409);
    final current =
        orders.firstWhere((o) => o['pedido_id'] == captured['pedido_id']);
    for (final item in current['itens'] as List) {
      item['quantidade_entregue'] = item['quantidade'];
    }
    current['status'] = 'fechado';
    current['revision']++;
    revision++;
  }
}

Future<PedidosProvider> mount(WidgetTester tester, DeliveryApi api,
    {Size size = const Size(768, 1024)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final provider = PedidosProvider(api: api);
  addTearDown(provider.dispose);
  await provider.refresh();
  await tester.pumpWidget(ChangeNotifierProvider.value(
      value: provider,
      child: MaterialApp(
          theme: appTheme(),
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.3)),
              child: child!),
          home: OrderQueueScreen(production: false, api: api))));
  await tester.pumpAndSettle();
  return provider;
}

void main() {
  for (final size in [const Size(768, 1024), const Size(1024, 768)]) {
    testWidgets('botão no cabeçalho só libera quando todos prontos em $size',
        (tester) async {
      final api = DeliveryApi();
      api.orders.first['itens'][0]['adicionais'] = [
        {'nome': 'Queijo extra', 'preco_centavos': 300},
      ];
      final provider = await mount(tester, api, size: size);
      expect(find.textContaining('Adicional: Queijo extra'), findsOneWidget);
      final button = find.byKey(const ValueKey('deliver-all-1'));
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
      api.orders.first['itens'][0]['quantidade_pronta'] = 5;
      api.orders.first['revision']++;
      api.revision++;
      await provider.refresh();
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(api.calls, [1]);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Senha 01'), findsNothing);
      expect(provider.filaEntrega.single['pedido_id'], 2);
      expect(api.orders.first['itens'][0]['quantidade_entregue'], 5);
      expect(api.orders.first['itens'][1]['quantidade_entregue'], 2);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
      'bloqueia duplo toque e mantém pedido em falha sem concluir localmente',
      (tester) async {
    final api = DeliveryApi()
      ..gate = Completer<void>()
      ..fail = true;
    api.orders.first['itens'][0]['quantidade_pronta'] = 5;
    await mount(tester, api);
    final button = find.byKey(const ValueKey('deliver-all-1'));
    await tester.tap(button);
    await tester.pump();
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    await tester.tap(button);
    await tester.pump();
    expect(api.calls, [1]);
    expect(find.text('Senha 01'), findsOneWidget);
    api.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Senha 01'), findsOneWidget);
    expect(find.text('Pedido atualizado em outro tablet.'), findsOneWidget);
    expect(api.orders.first['itens'][0]['quantidade_entregue'], 1);
    expect(tester.takeException(), isNull);
  });
}
