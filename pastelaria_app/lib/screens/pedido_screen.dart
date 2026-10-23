import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/pedidos_provider.dart';
import '../ui/app_ui.dart';
import 'novo_pedido_screen.dart';
import 'editar_pedidos_screen.dart';

class PedidoScreen extends StatelessWidget {
  const PedidoScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final p = context.watch<PedidosProvider>();
    final last = p.ultimoPedidoConfirmado;
    return Scaffold(
      appBar: AppBar(title: const Text('Atendimento'), actions: [
        TextButton.icon(
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const EditarPedidosScreen())),
            icon: const Icon(Icons.receipt_long_outlined),
            label: const Text('Pedidos do dia')),
        const SizedBox(width: 12)
      ]),
      body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 960),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Um bom atendimento começa aqui.',
                            style: TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
                                color: ink)),
                        const SizedBox(height: 8),
                        const Text(
                            'Monte o pedido, confira os itens e informe a senha ao cliente.',
                            style: TextStyle(fontSize: 18, color: mutedInk)),
                        const SizedBox(height: 24),
                        SurfaceCard(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              const Icon(Icons.add_shopping_cart,
                                  size: 38, color: brand),
                              const SizedBox(height: 16),
                              Text(
                                  p.itensPedidoAtual.isEmpty
                                      ? 'Novo pedido'
                                      : 'Continuar pedido',
                                  style: const TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w800)),
                              const SizedBox(height: 8),
                              Text(
                                  p.itensPedidoAtual.isEmpty
                                      ? 'Pastéis feitos na hora, salgados e bebidas.'
                                      : '${p.itensPedidoAtual.fold<int>(0, (n, i) => n + i.quantidade)} unidades na comanda em montagem.',
                                  style: const TextStyle(
                                      fontSize: 18, color: mutedInk)),
                              const SizedBox(height: 20),
                              FilledButton.icon(
                                  onPressed: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              const NovoPedidoScreen())),
                                  icon: const Icon(Icons.arrow_forward),
                                  label: Text(p.itensPedidoAtual.isEmpty
                                      ? 'Começar pedido'
                                      : 'Retomar comanda')),
                            ])),
                        const SizedBox(height: 20),
                        Wrap(spacing: 12, runSpacing: 12, children: [
                          StatusPill(
                              '${p.filaProducao.length} pedidos na cozinha',
                              icon: Icons.soup_kitchen_outlined,
                              color: brand),
                          StatusPill(
                              '${p.filaEntrega.length} pedidos em atendimento',
                              icon: Icons.shopping_bag_outlined)
                        ]),
                        if (last != null) ...[
                          const SizedBox(height: 24),
                          SurfaceCard(
                              child: Row(children: [
                            Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                    color: success.withValues(alpha: .08),
                                    borderRadius: BorderRadius.circular(14)),
                                child: Text(
                                    (last['numero'] as int) > 0
                                        ? '${last['numero']}'.padLeft(2, '0')
                                        : 'Balcão',
                                    style: const TextStyle(
                                        fontSize: 38,
                                        fontWeight: FontWeight.w800,
                                        color: success))),
                            const SizedBox(width: 20),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  const Text('Último pedido confirmado',
                                      style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 4),
                                  Text(
                                      money(((last['total'] as num) * 100)
                                          .round()),
                                      style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w800)),
                                  const Text('Pedido salvo no servidor',
                                      style: TextStyle(color: mutedInk))
                                ])),
                          ])),
                        ],
                      ])))),
    );
  }
}
