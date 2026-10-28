import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../ui/app_ui.dart';
import 'fila_entrega_screen.dart';
import '../models/pastel_extra.dart';

class EditarPedidoSelecionadoScreen extends StatefulWidget {
  final int pedidoId;
  final ApiService? api;
  const EditarPedidoSelecionadoScreen(
      {super.key, required this.pedidoId, this.api});
  @override
  State<EditarPedidoSelecionadoScreen> createState() =>
      _EditarPedidoSelecionadoScreenState();
}

class _EditarPedidoSelecionadoScreenState
    extends State<EditarPedidoSelecionadoScreen> {
  late Future<Map<String, dynamic>> _order;
  bool _busy = false;
  ApiService get _api => widget.api ?? ApiService();
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _order = _api.getPedidoPorId(widget.pedidoId);
  }

  Future<void> _action(bool cancel) async {
    final confirm = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
                title: Text(cancel
                    ? 'Cancelar este pedido?'
                    : 'Solicitar segunda via?'),
                content: Text(cancel
                    ? 'O pedido sairá das filas de produção e entrega. Itens já produzidos ou entregues precisam de conferência e não podem ser cancelados por aqui.'
                    : 'Confira a impressora antes de continuar. A segunda via pode duplicar um cupom que já saiu.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('Voltar')),
                  FilledButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: Text(
                          cancel ? 'Cancelar pedido' : 'Imprimir segunda via'))
                ]));
    if (confirm != true || !mounted) return;
    setState(() => _busy = true);
    try {
      if (cancel) {
        await _api.updatePedidoStatus(widget.pedidoId, 'cancelado');
      } else {
        await _api.reimprimirPedido(widget.pedidoId);
      }
      if (!mounted) return;
      if (cancel) {
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Segunda via adicionada à fila de impressão.')));
        setState(_load);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
      future: _order,
      builder: (context, snapshot) {
        final o = snapshot.data;
        final status = o?['status'] as String? ?? '';
        return Scaffold(
          appBar: AppBar(
              title: Text(o == null
                  ? 'Detalhes do pedido'
                  : o['numero_pedido'] > 0
                      ? 'Senha ${o['numero_pedido'].toString().padLeft(2, '0')}'
                      : 'Pedido de balcão'),
              actions: [
                IconButton(
                    tooltip: 'Solicitar segunda via',
                    onPressed: o == null || _busy ? null : () => _action(false),
                    icon: const Icon(Icons.print_outlined)),
                const SizedBox(width: 12)
              ]),
          body: snapshot.connectionState != ConnectionState.done
              ? const Center(child: CircularProgressIndicator())
              : o == null
                  ? Center(
                      child: Padding(
                          padding: const EdgeInsets.all(24),
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                            Text(
                                'Não foi possível carregar o pedido.\n${snapshot.error ?? ''}',
                                textAlign: TextAlign.center),
                            const SizedBox(height: 12),
                            FilledButton(
                                onPressed: () => setState(_load),
                                child: const Text('Tentar novamente'))
                          ])))
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      children: [
                          SurfaceCard(
                              child: Wrap(
                                  spacing: 24,
                                  runSpacing: 16,
                                  alignment: WrapAlignment.spaceBetween,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                          'Pedido interno ${o['pedido_id'] ?? o['id']}',
                                          style:
                                              const TextStyle(color: mutedInk)),
                                      const SizedBox(height: 10),
                                      StatusPill(
                                          status == 'aberto'
                                              ? 'Em atendimento'
                                              : status == 'fechado'
                                                  ? 'Entregue'
                                                  : 'Cancelado',
                                          color: status == 'fechado'
                                              ? success
                                              : status == 'cancelado'
                                                  ? brand
                                                  : mutedInk)
                                    ]),
                                Text(
                                    money(o['total_centavos'] as int? ??
                                        ((o['total_pedido'] as num) * 100)
                                            .round()),
                                    style: const TextStyle(
                                        fontSize: 30,
                                        fontWeight: FontWeight.w800))
                              ])),
                          if ((o['observacoes'] as String? ?? '').isNotEmpty)
                            Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                child: Text(o['observacoes'] as String,
                                    style: const TextStyle(
                                        fontSize: 19,
                                        fontWeight: FontWeight.w600))),
                          const SizedBox(height: 16),
                          const Text('Itens e andamento',
                              style: TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 12),
                          for (final i in o['itens'] as List) ...[
                            SurfaceCard(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Wrap(
                                      spacing: 20,
                                      runSpacing: 8,
                                      alignment: WrapAlignment.spaceBetween,
                                      children: [
                                        Text(
                                            '${i['quantidade']}× ${i['produto_nome']}',
                                            style: const TextStyle(
                                                fontSize: 22,
                                                fontWeight: FontWeight.w800)),
                                        Text(
                                            money(((i['subtotal'] as num) * 100)
                                                .round()),
                                            style: const TextStyle(
                                                fontSize: 21,
                                                fontWeight: FontWeight.w700))
                                      ]),
                                  if ((i['ingredientes'] as List).isNotEmpty)
                                    Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Text(
                                            (i['ingredientes'] as List)
                                                .join(' · '),
                                            style: const TextStyle(
                                                color: mutedInk,
                                                fontSize: 18))),
                                  for (final extra
                                      in PastelExtra.parse(i['adicionais']))
                                    Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Text(
                                            'Adicional: ${extra.description}',
                                            style: const TextStyle(
                                                color: brand, fontSize: 18))),
                                  if (i['observacoes_item'] != '')
                                    Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Text(
                                            'OBS: ${i['observacoes_item']}',
                                            style: const TextStyle(
                                                color: brand, fontSize: 17))),
                                  const SizedBox(height: 14),
                                  Wrap(spacing: 10, runSpacing: 8, children: [
                                    StatusPill(
                                        'Prontos: ${i['quantidade_pronta']}',
                                        color: success),
                                    StatusPill(
                                        'Entregues: ${i['quantidade_entregue']}',
                                        color: mutedInk),
                                    if (i['quantidade_cancelada'] > 0)
                                      StatusPill(
                                          'Cancelados: ${i['quantidade_cancelada']}',
                                          color: brand)
                                  ]),
                                ])),
                            const SizedBox(height: 12),
                          ],
                        ]),
          bottomNavigationBar: status != 'aberto'
              ? null
              : SafeArea(
                  top: false,
                  child: Container(
                      color: Colors.white,
                      padding: const EdgeInsets.all(16),
                      child: Wrap(
                          spacing: 12,
                          runSpacing: 10,
                          alignment: WrapAlignment.end,
                          children: [
                            OutlinedButton.icon(
                                onPressed: _busy ? null : () => _action(true),
                                icon: const Icon(Icons.cancel_outlined),
                                label: const Text('Cancelar pedido')),
                            FilledButton.icon(
                                onPressed: _busy
                                    ? null
                                    : () => Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                    builder: (_) =>
                                                        const FilaEntregaScreen()))
                                            .then((_) {
                                          if (mounted) setState(_load);
                                        }),
                                icon: const Icon(Icons.shopping_bag_outlined),
                                label: const Text('Conferir entrega'))
                          ]))),
        );
      });
}
