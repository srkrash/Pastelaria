// lib/screens/editar_pedido_selecionado.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';

class EditarPedidoSelecionadoScreen extends StatefulWidget {
  final int pedidoId;
  const EditarPedidoSelecionadoScreen({super.key, required this.pedidoId});

  @override
  State<EditarPedidoSelecionadoScreen> createState() => _EditarPedidoSelecionadoScreenState();
}

class _EditarPedidoSelecionadoScreenState extends State<EditarPedidoSelecionadoScreen> {
  final ApiService _apiService = ApiService();
  late Future<dynamic> _pedidoFuture;

  @override
  void initState() {
    super.initState();
    _pedidoFuture = _apiService.getPedidoPorId(widget.pedidoId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Detalhes do Pedido #${widget.pedidoId}'),
      ),
      body: FutureBuilder<dynamic>(
        future: _pedidoFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erro ao carregar detalhes do pedido: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!['itens'].isEmpty) {
            return const Center(child: Text('Pedido não encontrado ou sem itens.'));
          }

          final pedido = snapshot.data!;
          final itens = pedido['itens'] as List<dynamic>;
          final formatter = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
          final totalPedido = double.tryParse(pedido['total_pedido']?.toString() ?? '0.0') ?? 0.0;

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Número do Pedido e Valor Total
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pedido Nº ${pedido['numero_pedido']}',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Total: ${formatter.format(totalPedido)}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Itens do Pedido:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Divider(),

                // Lista de Itens do Pedido
                Expanded(
                  child: ListView.builder(
                    itemCount: itens.length,
                    itemBuilder: (context, index) {
                      final item = itens[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8.0),
                        child: ListTile(
                          title: Text(item['produto_nome']),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Quantidade: ${item['quantidade']}'),
                              if (item['ingredientes'] != null && item['ingredientes'].isNotEmpty)
                                Text('Ingredientes: ${item['ingredientes'].join(', ')}'),
                              if (item['observacoes_item'] != null && item['observacoes_item'].isNotEmpty)
                                Text('Observações: ${item['observacoes_item']}'),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                onPressed: () {
                                  // Lógica para diminuir a quantidade
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Diminuir quantidade')),
                                  );
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline),
                                onPressed: () {
                                  // Lógica para aumentar a quantidade
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Aumentar quantidade')),
                                  );
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () {
                                  // Lógica para excluir o item
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Excluir item')),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Botões de Ação do Pedido
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          // Lógica para salvar as alterações
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Salvar alterações')),
                          );
                        },
                        child: const Text('Salvar'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          // Lógica para cancelar alterações
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Cancelar alterações')),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                        ),
                        child: const Text('Cancelar'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          // Lógica para cancelar o pedido inteiro
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Cancelar pedido')),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        child: const Text('Cancelar Pedido'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
