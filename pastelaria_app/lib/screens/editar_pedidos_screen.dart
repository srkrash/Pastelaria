import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../ui/app_ui.dart';
import 'editar_pedido_selecionado.dart';

class EditarPedidosScreen extends StatefulWidget {
  final ApiService? api;
  const EditarPedidosScreen({super.key, this.api});
  @override
  State<EditarPedidosScreen> createState() => _EditarPedidosScreenState();
}

class _EditarPedidosScreenState extends State<EditarPedidosScreen> {
  late Future<List<dynamic>> _orders;
  String _filter = 'todos', _search = '';
  static const _labels = {
    'todos': 'Todos',
    'aberto': 'Em atendimento',
    'fechado': 'Entregues',
    'cancelado': 'Cancelados'
  };
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _orders = (widget.api ?? ApiService()).getPedidosHoje();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Pedidos do dia'), actions: [
          IconButton(
              tooltip: 'Atualizar pedidos',
              onPressed: () => setState(_load),
              icon: const Icon(Icons.refresh)),
          const SizedBox(width: 12)
        ]),
        body: Column(children: [
          Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                        onChanged: (s) => setState(() => _search = s),
                        decoration: const InputDecoration(
                            hintText:
                                'Buscar senha ou número interno do pedido',
                            prefixIcon: Icon(Icons.search))),
                    const SizedBox(height: 12),
                    Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        children: _labels.entries
                            .map((e) => ChoiceChip(
                                label: Text(e.value),
                                selected: _filter == e.key,
                                onSelected: (_) =>
                                    setState(() => _filter = e.key)))
                            .toList()),
                  ])),
          Expanded(
              child: FutureBuilder<List<dynamic>>(
                  future: _orders,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(
                          child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                        'Não foi possível carregar os pedidos.',
                                        style: TextStyle(
                                            fontSize: 21,
                                            fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 12),
                                    Text('${snapshot.error}',
                                        textAlign: TextAlign.center),
                                    const SizedBox(height: 16),
                                    FilledButton.icon(
                                        onPressed: () => setState(_load),
                                        icon: const Icon(Icons.refresh),
                                        label: const Text('Tentar novamente'))
                                  ])));
                    }
                    final orders = (snapshot.data ?? [])
                        .reversed
                        .where((o) =>
                            (_filter == 'todos' || o['status'] == _filter) &&
                            (_search.isEmpty ||
                                '${o['numero_pedido']}'
                                    .contains(_search.trim()) ||
                                '${o['pedido_id'] ?? o['id']}'
                                    .contains(_search.trim())))
                        .toList();
                    if (orders.isEmpty) {
                      return const Center(
                          child: Text('Nenhum pedido encontrado neste filtro.',
                              style: TextStyle(fontSize: 21)));
                    }
                    return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        itemCount: orders.length,
                        separatorBuilder: (_, index) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final o = orders[index];
                          final status = o['status'] as String;
                          final date = DateTime.tryParse(
                                  o['data_hora_pedido']?.toString() ?? '')
                              ?.toLocal();
                          return Material(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () async {
                                    await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) =>
                                                EditarPedidoSelecionadoScreen(
                                                    pedidoId: (o['pedido_id'] ??
                                                        o['id']) as int,
                                                    api: widget.api)));
                                    if (mounted) setState(_load);
                                  },
                                  child: Padding(
                                      padding: const EdgeInsets.all(18),
                                      child: Row(children: [
                                        Expanded(
                                            child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                              Text(
                                                  o['numero_pedido'] > 0
                                                      ? 'Senha ${o['numero_pedido'].toString().padLeft(2, '0')}'
                                                      : 'Balcão',
                                                  style: const TextStyle(
                                                      fontSize: 24,
                                                      fontWeight:
                                                          FontWeight.w800)),
                                              const SizedBox(height: 6),
                                              Text(
                                                  'Pedido ${o['pedido_id'] ?? o['id']}${date == null ? '' : ' · ${clockTime(date)}'}',
                                                  style: const TextStyle(
                                                      color: mutedInk)),
                                              const SizedBox(height: 10),
                                              StatusPill(
                                                  _labels[status] ?? status,
                                                  color: status == 'fechado'
                                                      ? success
                                                      : status == 'cancelado'
                                                          ? brand
                                                          : mutedInk)
                                            ])),
                                        const SizedBox(width: 12),
                                        Text(
                                            money(o['total_centavos'] as int? ??
                                                ((o['total_pedido'] as num) *
                                                        100)
                                                    .round()),
                                            style: const TextStyle(
                                                fontSize: 22,
                                                fontWeight: FontWeight.w800)),
                                        const SizedBox(width: 12),
                                        const Icon(Icons.chevron_right,
                                            color: mutedInk),
                                      ]))));
                        });
                  })),
        ]),
      );
}
