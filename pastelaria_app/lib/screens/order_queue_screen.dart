import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/pedidos_provider.dart';
import '../services/api_service.dart';
import '../ui/app_ui.dart';
import '../models/pastel_extra.dart';

class OrderQueueScreen extends StatefulWidget {
  final bool production;
  final ApiService? api;
  const OrderQueueScreen({super.key, required this.production, this.api});
  @override
  State<OrderQueueScreen> createState() => _OrderQueueScreenState();
}

class _OrderQueueScreenState extends State<OrderQueueScreen> {
  final Set<String> _busy = {};
  String _filter = 'all', _search = '';
  final _searchController = TextEditingController();
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  int _pending(Map<String, dynamic> i) =>
      (i['quantidade'] - i['quantidade_cancelada'] - i['quantidade_pronta'])
          as int;
  int _available(Map<String, dynamic> i) =>
      (i['quantidade_pronta'] - i['quantidade_entregue']) as int;
  List<Map<String, dynamic>> _items(Map<String, dynamic> p) =>
      (p['itens'] as List)
          .cast<Map<String, dynamic>>()
          .where((i) => !widget.production || i['produto_tipo'] == 'pastel')
          .toList();
  bool _partial(Map<String, dynamic> p) => _items(p).any((i) =>
      i['quantidade_entregue'] > 0 ||
      i['quantidade_pronta'] > 0 && _pending(i) > 0);
  bool _orderBusy(Map<String, dynamic> order) =>
      _busy.any((key) => key.startsWith('${order['pedido_id']}:'));
  bool _canDeliverAll(Map<String, dynamic> order) =>
      order['status'] == 'aberto' &&
      _items(order).every((item) => _pending(item) == 0) &&
      _items(order).any((item) => _available(item) > 0);

  Future<void> _deliverAll(Map<String, dynamic> order) async {
    if (_orderBusy(order)) return;
    final key = '${order['pedido_id']}:all';
    final provider = context.read<PedidosProvider>();
    setState(() => _busy.add(key));
    try {
      await (widget.api ?? ApiService()).deliverOrder(order);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      await provider.refresh();
      if (mounted) setState(() => _busy.remove(key));
    }
  }

  Future<void> _change(Map<String, dynamic> order, Map<String, dynamic> item,
      int available) async {
    var quantity = 1;
    final count = widget.production
        ? available
        : await showDialog<int>(
            context: context,
            builder: (dialogContext) => StatefulBuilder(
                builder: (context, update) => AlertDialog(
                      title: Text(widget.production
                          ? 'Concluir preparo'
                          : 'Registrar entrega'),
                      content: SizedBox(
                          width: 360,
                          child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    order['numero_pedido'] > 0
                                        ? 'Senha ${order['numero_pedido'].toString().padLeft(2, '0')}'
                                        : 'Pedido de balcão',
                                    style: const TextStyle(
                                        fontSize: 26,
                                        fontWeight: FontWeight.w800)),
                                const SizedBox(height: 8),
                                Text(item['produto_nome'] as String,
                                    style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700)),
                                if ((item['ingredientes'] as List).isNotEmpty)
                                  Text(
                                      (item['ingredientes'] as List).join(', '),
                                      style: const TextStyle(color: mutedInk)),
                                if (item['observacoes_item'] != '')
                                  Text('OBS: ${item['observacoes_item']}',
                                      style: const TextStyle(color: brand)),
                                const SizedBox(height: 20),
                                Center(
                                    child: QuantityStepper(
                                        value: quantity,
                                        max: available,
                                        onChanged: (v) =>
                                            update(() => quantity = v))),
                                const SizedBox(height: 12),
                                Center(
                                    child: TextButton(
                                        onPressed: () =>
                                            update(() => quantity = available),
                                        child: Text(
                                            'Selecionar todas: $available'))),
                                Text(
                                    widget.production
                                        ? 'O restante continuará aguardando preparo.'
                                        : 'Somente estas unidades serão marcadas como entregues.',
                                    style: const TextStyle(color: mutedInk)),
                              ])),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            child: const Text('Voltar')),
                        FilledButton(
                            onPressed: () =>
                                Navigator.pop(dialogContext, quantity),
                            child: const Text('Confirmar'))
                      ],
                    )));
    if (count == null || !mounted || _orderBusy(order)) return;
    final key = '${order['pedido_id']}:${item['item_id']}';
    setState(() => _busy.add(key));
    final provider = context.read<PedidosProvider>();
    try {
      await (widget.api ?? ApiService()).changeQuantity(
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

  Widget _item(Map<String, dynamic> p, Map<String, dynamic> i,
      PedidosProvider provider) {
    final available = widget.production ? _pending(i) : _available(i);
    final finished =
        i['quantidade_entregue'] == i['quantidade'] - i['quantidade_cancelada'];
    final details =
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('${i['quantidade']}× ${i['produto_nome']}',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
      if ((i['ingredientes'] as List).isNotEmpty)
        Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text((i['ingredientes'] as List).join(' · '),
                style: const TextStyle(fontSize: 18, color: mutedInk))),
      for (final extra in PastelExtra.parse(i['adicionais']))
        Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Adicional: ${extra.description}',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700, color: brand))),
      if (i['observacoes_item'] != '')
        Padding(
            padding: const EdgeInsets.only(top: 8),
            child: StatusPill('OBS: ${i['observacoes_item']}',
                color: brand, icon: Icons.info_outline)),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, children: [
        if (_pending(i) > 0)
          StatusPill('A produzir: ${_pending(i)}', color: brand),
        StatusPill('Disponíveis: ${_available(i)}',
            color: _available(i) > 0 ? success : mutedInk),
        StatusPill('Entregues: ${i['quantidade_entregue']}', color: mutedInk),
      ]),
    ]);
    final action = available > 0
        ? FilledButton.icon(
            onPressed: provider.error == null && !_orderBusy(p)
                ? () => _change(p, i, available)
                : null,
            style: FilledButton.styleFrom(
                backgroundColor: widget.production ? brand : success),
            icon: Icon(widget.production
                ? Icons.check_circle_outline
                : Icons.shopping_bag_outlined),
            label: Text(
                '${widget.production ? 'Concluir preparo' : 'Entregar'} · saldo $available'),
          )
        : Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: StatusPill(
                finished
                    ? 'Entregue'
                    : widget.production
                        ? 'Preparo concluído'
                        : 'Aguardando preparo',
                color: finished ? success : mutedInk,
                icon: finished ? Icons.check_circle_outline : Icons.schedule));
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: LayoutBuilder(
            builder: (context, c) => c.maxWidth >= 760
                ? Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                    Expanded(child: details),
                    const SizedBox(width: 20),
                    SizedBox(width: 255, child: action)
                  ])
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [details, const SizedBox(height: 14), action])));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PedidosProvider>();
    final orders =
        widget.production ? provider.filaProducao : provider.filaEntrega;
    final availableOrders =
        orders.where((o) => _items(o).any((i) => _available(i) > 0)).length;
    final partialOrders = orders.where(_partial).length;
    final visible = orders.where((o) {
      final matching = _search.trim().isEmpty ||
          '${o['numero_pedido']}'.padLeft(2, '0').contains(_search.trim()) ||
          o['numero_pedido'] <= 0 && 'balcão'.contains(_search.toLowerCase());
      return matching &&
          (_filter == 'all' ||
              _filter == 'partial' && _partial(o) ||
              _filter == 'ready' && _items(o).any((i) => _available(i) > 0));
    }).toList();
    final count = orders.expand(_items).fold<int>(
        0, (n, i) => n + (widget.production ? _pending(i) : _available(i)));
    return Scaffold(
      appBar: AppBar(
          title: Text(widget.production
              ? 'Produção de pastéis'
              : 'Entrega dos pedidos'),
          actions: [
            IconButton(
                onPressed: provider.refresh,
                icon: const Icon(Icons.refresh),
                tooltip: 'Sincronizar'),
            const SizedBox(width: 12)
          ]),
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (provider.error != null)
          MaterialBanner(
              content: Text(
                  '${provider.error}\nOs dados abaixo podem estar desatualizados.'),
              actions: [
                TextButton(
                    onPressed: provider.refresh,
                    child: const Text('Tentar novamente'))
              ]),
        Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    StatusPill(
                        '$count ${widget.production ? count == 1 ? 'pastel a produzir' : 'pastéis a produzir' : count == 1 ? 'unidade disponível' : 'unidades disponíveis'}',
                        color: widget.production ? brand : success,
                        icon: widget.production
                            ? Icons.soup_kitchen_outlined
                            : Icons.shopping_bag_outlined),
                    Text(
                        '${orders.length} pedidos · ${provider.lastSync == null ? 'aguardando conexão' : 'atualizado às ${clockTime(provider.lastSync!)}'}',
                        style: const TextStyle(color: mutedInk)),
                  ]),
              const SizedBox(height: 12),
              Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ChoiceChip(
                        label: Text('Todos (${orders.length})'),
                        selected: _filter == 'all',
                        onSelected: (_) => setState(() => _filter = 'all')),
                    if (!widget.production)
                      ChoiceChip(
                          label: Text('Disponíveis ($availableOrders)'),
                          selected: _filter == 'ready',
                          onSelected: (_) => setState(() => _filter = 'ready')),
                    ChoiceChip(
                        label: Text('Parciais ($partialOrders)'),
                        selected: _filter == 'partial',
                        onSelected: (_) => setState(() => _filter = 'partial')),
                    SizedBox(
                        width: 190,
                        child: TextField(
                            controller: _searchController,
                            onChanged: (v) => setState(() => _search = v),
                            decoration: const InputDecoration(
                                hintText: 'Buscar senha',
                                prefixIcon: Icon(Icons.search),
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 12)))),
                  ]),
            ])),
        Expanded(
            child: visible.isEmpty
                ? Center(
                    child: Padding(
                        padding: const EdgeInsets.all(24),
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(
                              provider.error != null
                                  ? Icons.wifi_off
                                  : Icons.task_alt,
                              size: 48,
                              color: mutedInk),
                          const SizedBox(height: 14),
                          Text(
                              provider.error != null
                                  ? 'Não foi possível confirmar a fila.'
                                  : provider.lastSync == null
                                      ? 'Carregando pedidos…'
                                      : orders.isEmpty
                                          ? 'Nenhum pedido pendente.'
                                          : 'Nenhum pedido neste filtro.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.w700)),
                          if (orders.isNotEmpty)
                            TextButton(
                                onPressed: () => setState(() {
                                      _filter = 'all';
                                      _search = '';
                                      _searchController.clear();
                                    }),
                                child: const Text('Mostrar todos os pedidos'))
                        ])))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    itemCount: visible.length,
                    separatorBuilder: (_, index) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final p = visible[index];
                      final trip =
                          (p['observacoes'] as String).contains('[Viagem]');
                      final note = (p['observacoes'] as String)
                          .replaceFirst(RegExp(r'^\[(Consumo|Viagem)\]\s*'), '')
                          .trim();
                      final created =
                          DateTime.parse(p['data_hora_pedido'] as String)
                              .toLocal();
                      return SurfaceCard(
                          key: ValueKey(p['pedido_id']),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                        child: Text(
                                            p['numero_pedido'] > 0
                                                ? 'Senha ${p['numero_pedido'].toString().padLeft(2, '0')}'
                                                : 'Balcão',
                                            style: const TextStyle(
                                                fontSize: 34,
                                                fontWeight: FontWeight.w900,
                                                color: ink))),
                                    if (!widget.production) ...[
                                      const SizedBox(width: 12),
                                      Tooltip(
                                        message: _canDeliverAll(p)
                                            ? 'Entregar todos os itens restantes deste pedido'
                                            : 'Aguardando todos os pastéis ficarem prontos',
                                        child: FilledButton.icon(
                                          key: ValueKey(
                                              'deliver-all-${p['pedido_id']}'),
                                          onPressed: provider.error == null &&
                                                  !_orderBusy(p) &&
                                                  _canDeliverAll(p)
                                              ? () => _deliverAll(p)
                                              : null,
                                          style: FilledButton.styleFrom(
                                              backgroundColor: success),
                                          icon: _busy.contains(
                                                  '${p['pedido_id']}:all')
                                              ? const SizedBox(
                                                  width: 18,
                                                  height: 18,
                                                  child:
                                                      CircularProgressIndicator(
                                                          strokeWidth: 2))
                                              : const Icon(Icons.done_all),
                                          label: const Text('Entregar tudo'),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                    spacing: 16,
                                    runSpacing: 8,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      StatusPill(trip ? 'Viagem' : 'No local',
                                          color: trip
                                              ? const Color(0xFF285C8C)
                                              : brand,
                                          icon: trip
                                              ? Icons.takeout_dining_outlined
                                              : Icons.restaurant_outlined),
                                      Text(
                                          '${clockTime(created)} · há ${DateTime.now().difference(created).inMinutes.clamp(0, 9999)} min',
                                          style: const TextStyle(
                                              fontSize: 16, color: mutedInk)),
                                    ]),
                                if (note.isNotEmpty)
                                  Padding(
                                      padding: const EdgeInsets.only(top: 12),
                                      child: Text(note,
                                          style: const TextStyle(
                                              fontSize: 19,
                                              fontWeight: FontWeight.w700,
                                              color: brand))),
                                const SizedBox(height: 12),
                                for (final i in _items(p)) ...[
                                  const Divider(height: 1),
                                  _item(p, i, provider)
                                ],
                              ]));
                    },
                  )),
      ]),
    );
  }
}
