import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pastelaria_app/providers/pedidos_provider.dart';
import 'package:pastelaria_app/screens/order_queue_screen.dart';
import 'package:pastelaria_app/services/api_service.dart';

class SnapshotApi extends ApiService {
  Map<String, dynamic> data;
  SnapshotApi(this.data);
  @override
  Future<Map<String, dynamic>> snapshot() async => data;
}
Map<String, dynamic> order(int id) => {
  'pedido_id': id, 'numero_pedido': id, 'status': 'aberto', 'revision': 1,
  'data_hora_pedido': DateTime.now().toUtc().toIso8601String(),
  'observacoes': '[Viagem] Sem guardanapo',
  'itens': [{'item_id': 1, 'produto_nome': 'Pastel', 'produto_tipo': 'pastel', 'quantidade': 5, 'quantidade_pronta': 2, 'quantidade_entregue': 1, 'quantidade_cancelada': 0, 'ingredientes': ['Carne', 'Queijo'], 'observacoes_item': 'Sem cebola'}],
};
void main() {
  for (final production in [true, false]) {
    testWidgets('${production ? 'Cozinha' : 'Entrega'} renderiza quantidades sem overflow no tablet', (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = SnapshotApi({'revision': 1, 'pedidos': [order(1), order(2)]});
      final provider = PedidosProvider(api: api);
      await provider.refresh();
      await tester.pumpWidget(ChangeNotifierProvider.value(value: provider, child: MaterialApp(home: OrderQueueScreen(production: production))));
      await tester.pumpAndSettle();
      expect(find.text('Senha 01'), findsOneWidget);
      expect(find.text('Disponíveis: 1'), findsWidgets);
      expect(find.text('Entregues: 1'), findsWidgets);
      expect(find.textContaining(production ? 'saldo 3' : 'saldo 1'), findsWidgets);
      expect(tester.takeException(), isNull);
      api.data = {'revision': 2, 'pedidos': [order(2)]};
      await provider.refresh(); await tester.pumpAndSettle();
      expect(find.text('Senha 01'), findsNothing);
      expect(find.text('Senha 02'), findsOneWidget);
      // Older snapshot cannot restore or remove a different card.
      api.data = {'revision': 1, 'pedidos': [order(1)]};
      await provider.refresh(); await tester.pumpAndSettle();
      expect(find.text('Senha 02'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink()); provider.dispose();
    });
  }
}
