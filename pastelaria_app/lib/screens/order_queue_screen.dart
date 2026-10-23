import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/pedidos_provider.dart';
import '../services/api_service.dart';

class OrderQueueScreen extends StatefulWidget {
  final bool production;
  const OrderQueueScreen({super.key, required this.production});
  @override
  State<OrderQueueScreen> createState() => _OrderQueueScreenState();
}

class _OrderQueueScreenState extends State<OrderQueueScreen> {
  final Set<String> _busy = {};

  Future<void> _change(Map<String, dynamic> order, Map<String, dynamic> item,
      int available) async {
    var quantity = 1;
    final count = await showDialog<int>(
        context: context,
        builder: (context) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
                  title: Text(widget.production
                      ? 'Marcar como pronto'
                      : 'Registrar entrega'),
                  content: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(
                        '${item['produto_nome']} · senha ${order['numero_pedido'] > 0 ? order['numero_pedido'] : 'balcão'}'),
                    const SizedBox(height: 16),
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(
                          onPressed: quantity > 1
                              ? () => setDialogState(() => quantity--)
                              : null,
                          icon: const Icon(Icons.remove_circle),
                          iconSize: 40),
                      Text('$quantity',
                          style: const TextStyle(
                              fontSize: 32, fontWeight: FontWeight.bold)),
                      IconButton(
                          onPressed: quantity < available
                              ? () => setDialogState(() => quantity++)
                              : null,
                          icon: const Icon(Icons.add_circle),
                          iconSize: 40),
                    ]),
                    TextButton(
                        onPressed: () =>
                            setDialogState(() => quantity = available),
                        child: Text('Selecionar saldo: $available')),
                  ]),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancelar')),
                    FilledButton(
                        onPressed: () => Navigator.pop(context, quantity),
                        child: const Text('Confirmar'))
                  ],
                )));
    if (count == null || !mounted) return;
    final key = '${order['pedido_id']}:${item['item_id']}';
    setState(() => _busy.add(key));
    final provider = context.read<PedidosProvider>();
    try {
      await ApiService().changeQuantity(
          order, item['item_id'] as int, count, widget.production);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      await provider.refresh();
      if (mounted) setState(() => _busy.remove(key));
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PedidosProvider>();
    final orders =
        widget.production ? provider.filaProducao : provider.filaEntrega;
    return Scaffold(
      appBar: AppBar(
          title: Text(widget.production
              ? 'Produção de pastéis'
              : 'Entrega dos pedidos'),
          actions: [
            IconButton(
                onPressed: provider.refresh,
                icon: const Icon(Icons.refresh),
                tooltip: 'Sincronizar')
          ]),
      body: Column(children: [
        if (provider.error != null)
          MaterialBanner(
              content: Text(
                  '${provider.error}\nOs dados abaixo podem estar desatualizados.'),
              actions: [
                TextButton(
                    onPressed: provider.refresh,
                    child: const Text('Tentar novamente'))
              ]),
        if (provider.loading) const LinearProgressIndicator(),
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                    '${orders.length} pedidos · ${provider.lastSync == null ? 'aguardando conexão' : 'última atualização ${TimeOfDay.fromDateTime(provider.lastSync!).format(context)}'}'))),
        Expanded(
            child: orders.isEmpty
                ? Center(
                    child: Text(
                        provider.error != null
                            ? 'Não foi possível confirmar a fila.'
                            : provider.lastSync == null
                                ? 'Carregando pedidos…'
                                : 'Nenhum pedido pendente.',
                        style: const TextStyle(fontSize: 22)))
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: orders.length,
                    itemBuilder: (context, index) {
                      final order = orders[index];
                      final items = (order['itens'] as List)
                          .cast<Map<String, dynamic>>()
                          .where((i) =>
                              !widget.production ||
                              i['produto_tipo'] == 'pastel')
                          .toList();
                      final trip =
                          (order['observacoes'] as String).contains('[Viagem]');
                      final created =
                          DateTime.parse(order['data_hora_pedido'] as String)
                              .toLocal();
                      return Card(
                          key: ValueKey(order['pedido_id']),
                          color: trip
                              ? Colors.blue.shade50
                              : Colors.orange.shade50,
                          margin: const EdgeInsets.only(bottom: 16),
                          child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Wrap(
                                        spacing: 24,
                                        runSpacing: 6,
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        children: [
                                          Text(
                                              order['numero_pedido'] > 0
                                                  ? 'Senha ${order['numero_pedido'].toString().padLeft(2, '0')}'
                                                  : 'Balcão',
                                              style: const TextStyle(
                                                  fontSize: 32,
                                                  fontWeight: FontWeight.bold)),
                                          Text(
                                              '${TimeOfDay.fromDateTime(created).format(context)} · ${DateTime.now().difference(created).inMinutes} min',
                                              style: const TextStyle(
                                                  fontSize: 18)),
                                        ]),
                                    if (order['observacoes'] != '')
                                      Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 10),
                                          child: Text(
                                              order['observacoes'] as String,
                                              style: const TextStyle(
                                                  fontSize: 20,
                                                  fontWeight:
                                                      FontWeight.w600))),
                                    for (final item in items) ...[
                                      const Divider(),
                                      Text(
                                          '${item['quantidade']}× ${item['produto_nome']}',
                                          style: const TextStyle(
                                              fontSize: 23,
                                              fontWeight: FontWeight.bold)),
                                      if ((item['ingredientes'] as List)
                                          .isNotEmpty)
                                        Text(
                                            (item['ingredientes'] as List)
                                                .join(', '),
                                            style:
                                                const TextStyle(fontSize: 20)),
                                      if (item['observacoes_item'] != '')
                                        Text('OBS: ${item['observacoes_item']}',
                                            style: const TextStyle(
                                                fontSize: 20,
                                                color: Colors.red)),
                                      Text(
                                          'Prontos: ${item['quantidade_pronta']}/${item['quantidade'] - item['quantidade_cancelada']} · Entregues: ${item['quantidade_entregue']}',
                                          style: const TextStyle(fontSize: 18)),
                                      Builder(builder: (context) {
                                        final int available = widget.production
                                            ? item['quantidade'] -
                                                item['quantidade_cancelada'] -
                                                item['quantidade_pronta']
                                            : item['quantidade_pronta'] -
                                                item['quantidade_entregue'];
                                        return Padding(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 10),
                                            child: FilledButton.icon(
                                              onPressed: available > 0 &&
                                                      provider.error == null &&
                                                      !_busy.contains(
                                                          '${order['pedido_id']}:${item['item_id']}')
                                                  ? () => _change(
                                                      order, item, available)
                                                  : null,
                                              icon: Icon(widget.production
                                                  ? Icons.check_circle
                                                  : Icons.delivery_dining),
                                              label: Text(available > 0
                                                  ? '${widget.production ? 'Concluir preparo' : 'Entregar'} · saldo $available'
                                                  : widget.production
                                                      ? 'Preparo concluído'
                                                      : item['quantidade_entregue'] ==
                                                              item['quantidade'] -
                                                                  item[
                                                                      'quantidade_cancelada']
                                                          ? 'Entregue'
                                                          : 'Aguardando preparo'),
                                              style: FilledButton.styleFrom(
                                                  minimumSize:
                                                      const Size(220, 56),
                                                  textStyle: const TextStyle(
                                                      fontSize: 19)),
                                            ));
                                      }),
                                    ],
                                  ])));
                    },
                  )),
      ]),
    );
  }
}
