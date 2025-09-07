// lib/screens/editar_pedidos_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../screens/editar_pedido_selecionado.dart';

class EditarPedidosScreen extends StatefulWidget {
  const EditarPedidosScreen({super.key});

  @override
  State<EditarPedidosScreen> createState() => _EditarPedidosScreenState();
}

class _EditarPedidosScreenState extends State<EditarPedidosScreen> {
  final ApiService _apiService = ApiService();
  late Future<List<dynamic>> _pedidosFuture;
  String _statusFiltro = 'todos'; // Status inicial do filtro

  @override
  void initState() {
    super.initState();
    _fetchPedidos();
  }

  void _fetchPedidos() {
    setState(() {
      _pedidosFuture = _apiService.getPedidosHoje();
    });
  }

  void _aplicarFiltro(String? novoStatus) {
    if (novoStatus != null) {
      setState(() {
        _statusFiltro = novoStatus;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pedidos do Dia'),
        actions: [
          // Adicionar um botão de recarregar para facilitar os testes
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchPedidos,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filtro de status
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                const Text('Filtrar por Status:', style: TextStyle(fontWeight: FontWeight.bold)),
                DropdownButton<String>(
                  value: _statusFiltro,
                  items: const [
                    DropdownMenuItem(value: 'todos', child: Text('Todos')),
                    DropdownMenuItem(value: 'aberto', child: Text('Em Aberto')),
                    DropdownMenuItem(value: 'fechado', child: Text('Finalizado')),
                    DropdownMenuItem(value: 'cancelado', child: Text('Cancelado')),
                  ],
                  onChanged: _aplicarFiltro,
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<dynamic>>(
              future: _pedidosFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Erro ao carregar pedidos: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('Nenhum pedido encontrado hoje.'));
                }
                final pedidos = snapshot.data!;

                final pedidosFiltrados = _statusFiltro == 'todos'
                    ? pedidos
                    : pedidos.where((pedido) => pedido['status'] == _statusFiltro).toList();

                final formatter = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

                return ListView.builder(
                  itemCount: pedidosFiltrados.length,
                  itemBuilder: (context, index) {
                    final pedido = pedidosFiltrados[index];
                    final totalPedido = double.tryParse(pedido['total_pedido']?.toString() ?? '0.0') ?? 0.0;
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                      child: ListTile(
                        leading: const Icon(Icons.receipt, color: Colors.blue),
                        title: Text(
                          'Pedido Nº ${pedido['numero_pedido']}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'Status: ${pedido['status']}',
                        ),
                        trailing: Text(
                          formatter.format(totalPedido),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16.0,
                            color: Colors.green,
                          ),
                        ),
                        onTap: () {
                          // Lógica de navegação será adicionada aqui.
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => EditarPedidoSelecionadoScreen(
                                pedidoId: pedido['id'],
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
