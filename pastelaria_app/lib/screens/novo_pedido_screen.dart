import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/item_pedido.dart';
import '../providers/pedidos_provider.dart';
import '../services/api_service.dart';
import '../services/app_settings.dart';
import '../ui/app_ui.dart';
import 'add_pastel_screen.dart';
import 'add_product_screen.dart';

class NovoPedidoScreen extends StatefulWidget {
  final ApiService? api;
  const NovoPedidoScreen({super.key, this.api});
  @override
  State<NovoPedidoScreen> createState() => _NovoPedidoScreenState();
}

class _NovoPedidoScreenState extends State<NovoPedidoScreen> {
  final _notes = TextEditingController();
  bool _busy = false;
  String? _fingerprint;
  String _commandId = newCommandId();
  @override
  void initState() {
    super.initState();
    _notes.text = context.read<PedidosProvider>().draftNotes;
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _addPastel() async {
    final result = await Navigator.push<Map<String, dynamic>>(
        context, MaterialPageRoute(builder: (_) => const AddPastelScreen()));
    if (result == null || !mounted) return;
    context.read<PedidosProvider>().adicionarItem(ItemPedido(
        id: 0,
        pedidoId: 0,
        numeroPedido: 0,
        quantidade: result['quantidade'] as int,
        produtoNome: 'Pastel',
        statusItem: 'aguardando',
        preco: 0,
        ingredientes: List<String>.from(result['ingredientes'] as List),
        observacoesItem: result['observacoesItem'] as String));
  }

  Future<void> _addProduct(String type) async {
    final result = await Navigator.push<List<ItemPedido>>(context,
        MaterialPageRoute(builder: (_) => AddProductScreen(productType: type)));
    if (result == null || !mounted) return;
    for (final item in result) {
      context.read<PedidosProvider>().adicionarItem(item);
    }
  }

  Future<void> _discard(PedidosProvider p) async {
    if (p.itensPedidoAtual.isEmpty) return;
    final discard = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
                title: const Text('Limpar esta comanda?'),
                content:
                    const Text('Os itens ainda não enviados serão removidos.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('Manter pedido')),
                  FilledButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('Limpar comanda'))
                ]));
    if (discard == true && mounted) {
      p.limparPedido();
      _notes.clear();
    }
  }

  Future<void> _confirm(PedidosProvider p) async {
    if (_busy || p.itensPedidoAtual.isEmpty) return;
    FocusScope.of(context).unfocus();
    final payload = <String, dynamic>{
      'observacoes_pedido': '[${p.draftType}] ${_notes.text.trim()}',
      'itens': p.itensPedidoAtual
          .map((i) => {
                'produto_nome': i.produtoNome,
                'quantidade': i.quantidade,
                'ingredientes': i.ingredientes
                    .map((s) => {'nome': s, 'quantidade': 1})
                    .toList(),
                'observacoes_item': i.observacoesItem
              })
          .toList(),
    };
    final fingerprint = jsonEncode(payload);
    if (_fingerprint != fingerprint) {
      _fingerprint = fingerprint;
      _commandId = newCommandId();
    }
    payload['command_id'] = _commandId;
    setState(() => _busy = true);
    try {
      final result =
          await (widget.api ?? ApiService()).inserirPedido('pedidos', payload);
      p.setUltimoPedido(result['numero_pedido'] as int,
          (result['total_pedido'] as num).toDouble());
      p.limparPedido();
      await p.refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result['numero_pedido'] > 0
              ? 'Pedido confirmado · senha ${result['numero_pedido']}'
              : 'Pedido de balcão confirmado')));
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _categories() =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Adicionar ao pedido',
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
        const SizedBox(height: 14),
        FilledButton.icon(
            onPressed: _addPastel,
            icon: const Icon(Icons.restaurant),
            label: const Text('Pastel personalizado')),
        const SizedBox(height: 10),
        OutlinedButton.icon(
            onPressed: () => _addProduct('salgado'),
            icon: const Icon(Icons.bakery_dining_outlined),
            label: const Text('Salgados')),
        const SizedBox(height: 10),
        OutlinedButton.icon(
            onPressed: () => _addProduct('bebida'),
            icon: const Icon(Icons.local_drink_outlined),
            label: const Text('Bebidas')),
      ]);
  Widget _type(PedidosProvider p) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Como vai ser servido?',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                  value: 'Consumo',
                  label: Text('No local'),
                  icon: Icon(Icons.restaurant_outlined)),
              ButtonSegment(
                  value: 'Viagem',
                  label: Text('Viagem'),
                  icon: Icon(Icons.takeout_dining_outlined))
            ],
            selected: {
              p.draftType
            },
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => p.draftType = s.single)),
      ]);
  Widget _observations(PedidosProvider p) => TextField(
      controller: _notes,
      onChanged: (v) => p.draftNotes = v,
      minLines: 2,
      maxLines: 3,
      decoration: const InputDecoration(
          labelText: 'Observação do pedido',
          hintText: 'Ex.: separar bebidas, embalar junto',
          alignLabelWithHint: true));
  Widget _comanda(PedidosProvider p, bool wide) {
    final items = p.itensPedidoAtual;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(children: [
            const Expanded(
                child: Text('Comanda',
                    style:
                        TextStyle(fontSize: 23, fontWeight: FontWeight.w800))),
            Text('${items.length} ${items.length == 1 ? 'item' : 'itens'}',
                style: const TextStyle(color: mutedInk))
          ])),
      Expanded(
          child: items.isEmpty
              ? SurfaceCard(
                  child: Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.receipt_long_outlined,
                      size: 48, color: mutedInk),
                  const SizedBox(height: 12),
                  const Text('Sua comanda começa aqui',
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  const Text('Adicione um pastel, salgado ou bebida.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: mutedInk, fontSize: 17)),
                  if (!wide) ...[
                    const SizedBox(height: 16),
                    FilledButton(
                        onPressed: _addPastel,
                        child: const Text('Escolher recheios'))
                  ]
                ])))
              : ListView.separated(
                  itemCount: items.length + (wide ? 0 : 1),
                  separatorBuilder: (_, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    if (index == items.length) {
                      return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: _observations(p));
                    }
                    final i = items[index];
                    return SurfaceCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                        child: Text(i.produtoNome,
                                            style: const TextStyle(
                                                fontSize: 21,
                                                fontWeight: FontWeight.w800))),
                                    Text(money(itemUnitCents(i) * i.quantidade),
                                        style: const TextStyle(
                                            fontSize: 21,
                                            fontWeight: FontWeight.w800))
                                  ]),
                              if (i.ingredientes.isNotEmpty)
                                Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(i.ingredientes.join(' · '),
                                        style: const TextStyle(
                                            fontSize: 17, color: mutedInk))),
                              if (i.observacoesItem.isNotEmpty)
                                Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text('OBS: ${i.observacoesItem}',
                                        style: const TextStyle(
                                            color: brand,
                                            fontWeight: FontWeight.w600))),
                              const SizedBox(height: 12),
                              Row(children: [
                                QuantityStepper(
                                    value: i.quantidade,
                                    label: i.produtoNome,
                                    onChanged: (v) =>
                                        p.alterarQuantidade(i, v)),
                                const Spacer(),
                                IconButton(
                                    tooltip: 'Remover ${i.produtoNome}',
                                    onPressed: () {
                                      p.removerItem(i);
                                      ScaffoldMessenger.of(context)
                                          .hideCurrentSnackBar();
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(SnackBar(
                                              content: Text(
                                                  '${i.produtoNome} removido'),
                                              action: SnackBarAction(
                                                  label: 'Desfazer',
                                                  onPressed: () => p
                                                      .inserirItem(index, i))));
                                    },
                                    icon: const Icon(Icons.delete_outline,
                                        color: mutedInk))
                              ]),
                            ]));
                  },
                )),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PedidosProvider>();
    final units = p.itensPedidoAtual.fold<int>(0, (n, i) => n + i.quantidade);
    final total = p.itensPedidoAtual
        .fold<int>(0, (n, i) => n + itemUnitCents(i) * i.quantidade);
    return PopScope(
        canPop: !_busy,
        child: Scaffold(
          appBar: AppBar(title: const Text('Montar pedido'), actions: [
            TextButton.icon(
                onPressed: _busy ? null : () => _discard(p),
                icon: const Icon(Icons.delete_sweep_outlined),
                label: const Text('Limpar')),
            const SizedBox(width: 12)
          ]),
          body: AbsorbPointer(
              absorbing: _busy,
              child: LayoutBuilder(builder: (context, c) {
                final wide = c.maxWidth >= 900;
                return Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: wide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                                Expanded(child: _comanda(p, true)),
                                const SizedBox(width: 20),
                                SizedBox(
                                    width: 300,
                                    child: SingleChildScrollView(
                                        child: SurfaceCard(
                                            child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.stretch,
                                                children: [
                                          _categories(),
                                          const Padding(
                                              padding: EdgeInsets.symmetric(
                                                  vertical: 16),
                                              child: Divider()),
                                          _type(p),
                                          const SizedBox(height: 24),
                                          _observations(p)
                                        ]))))
                              ])
                        : Column(children: [
                            SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(children: [
                                  FilledButton.icon(
                                      onPressed: _addPastel,
                                      icon: const Icon(Icons.restaurant),
                                      label: const Text('Pastel')),
                                  const SizedBox(width: 10),
                                  OutlinedButton.icon(
                                      onPressed: () => _addProduct('salgado'),
                                      icon: const Icon(
                                          Icons.bakery_dining_outlined),
                                      label: const Text('Salgados')),
                                  const SizedBox(width: 10),
                                  OutlinedButton.icon(
                                      onPressed: () => _addProduct('bebida'),
                                      icon: const Icon(
                                          Icons.local_drink_outlined),
                                      label: const Text('Bebidas'))
                                ])),
                            const SizedBox(height: 16),
                            _type(p),
                            const SizedBox(height: 18),
                            Expanded(child: _comanda(p, false)),
                          ]));
              })),
          bottomNavigationBar: SafeArea(
              top: false,
              child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: const BoxDecoration(
                      color: Colors.white,
                      border:
                          Border(top: BorderSide(color: Color(0xFFE0E5DF)))),
                  child: Row(children: [
                    Expanded(
                        child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(
                              '$units ${units == 1 ? 'unidade' : 'unidades'} · total',
                              style: const TextStyle(color: mutedInk)),
                          Text(money(total),
                              style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  color: ink))
                        ])),
                    FilledButton.icon(
                        onPressed:
                            units > 0 && !_busy ? () => _confirm(p) : null,
                        icon: _busy
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.check),
                        label: Text(_busy ? 'Enviando…' : 'Confirmar pedido'))
                  ]))),
        ));
  }
}
