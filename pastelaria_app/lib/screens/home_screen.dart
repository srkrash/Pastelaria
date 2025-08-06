import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/pedidos_provider.dart';
import '../models/item_pedido.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // No início, busca a lista inicial de pedidos
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<PedidosProvider>(context, listen: false).fetchItens();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Escuta o PedidosProvider para reconstruir a tela quando os dados mudam
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fila de Produção'),
      ),
      body: Consumer<PedidosProvider>(
        builder: (context, pedidosProvider, child) {
          // Se a lista estiver vazia, exibe uma mensagem
          if (pedidosProvider.itensPedido.isEmpty) {
            return const Center(
              child: Text('Nenhum pedido na fila.'),
            );
          }
          // Caso contrário, exibe a lista de itens
          return ListView.builder(
            itemCount: pedidosProvider.itensPedido.length,
            itemBuilder: (context, index) {
              final item = pedidosProvider.itensPedido[index];
              return _buildPedidoCard(context, item);
            },
          );
        },
      ),
    );
  }

  Widget _buildPedidoCard(BuildContext context, ItemPedido item) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pedido #${item.pedidoId} - Produto: ${item.produtoNome}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Quantidade: ${item.quantidade}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 4),
            // Exibe os ingredientes se existirem
            if (item.ingredientes.isNotEmpty)
              Text(
                'Ingredientes: ${item.ingredientes.join(', ')}',
                style: const TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
              ),
            const SizedBox(height: 12),
            // Botão para atualizar o status do item
            ElevatedButton(
              onPressed: () {
                _showStatusUpdateDialog(context, item);
              },
              child: Text('Mudar Status: ${item.statusItem}'),
            ),
          ],
        ),
      ),
    );
  }

  void _showStatusUpdateDialog(BuildContext context, ItemPedido item) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Atualizar Status'),
          content: const Text('Deseja mover este item para "em_preparacao"?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                // Chama o método do provider para atualizar o status
                Provider.of<PedidosProvider>(context, listen: false).updateStatusItem(item.id, 'em_preparacao');
                Navigator.of(context).pop();
              },
              child: const Text('Confirmar'),
            ),
          ],
        );
      },
    );
  }
}