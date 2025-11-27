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

  // Helper para obter a cor do status, seguindo o tema com destaque em âmbar para 'Em Aberto'
  Color _getStatusColor(String status) {
    switch (status) {
      case 'aberto':
        return Colors.amber.shade700; // Cor do tema para o status de 'Em Aberto'
      case 'fechado':
        return Colors.green.shade700;
      case 'cancelado':
        return Colors.red.shade700;
      default:
        return Colors.blueGrey;
    }
  }

  // Helper para obter o texto formatado do status
  String _getStatusText(String status) {
    switch (status) {
      case 'aberto':
        return 'Em Aberto';
      case 'fechado':
        return 'Finalizado';
      case 'cancelado':
        return 'Cancelado';
      default:
        return status;
    }
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
        backgroundColor: Colors.deepOrange, // Aplicando o tema ambar/laranja
        foregroundColor: Colors.white, // Ícones e texto em branco
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
                  items: [
                    const DropdownMenuItem(value: 'todos', child: Text('Todos')),
                    DropdownMenuItem(value: 'aberto', child: Text('Em Aberto')),
                    const DropdownMenuItem(value: 'fechado', child: Text('Finalizado')),
                    const DropdownMenuItem(value: 'cancelado', child: Text('Cancelado')),
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
                
                if (pedidosFiltrados.isEmpty) {
                  return Center(child: Text('Nenhum pedido com status "${_getStatusText(_statusFiltro)}" encontrado.'));
                }

                final formatter = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

                return ListView.builder(
                  itemCount: pedidosFiltrados.length,
                  itemBuilder: (context, index) {
                    final pedido = pedidosFiltrados[index];
                    final totalPedido = double.tryParse(pedido['total_pedido']?.toString() ?? '0.0') ?? 0.0;
                    final status = pedido['status']?.toString() ?? 'desconhecido';
                    
                    return Card(
                      elevation: 3,
                      margin: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: const Icon(Icons.receipt, color: Colors.deepOrange, size: 40), // Aumentado
                          title: Text(
                            'Pedido Nº ${pedido['numero_pedido']}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22), // Aumentado
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              'Status: ${_getStatusText(status)}',
                              style: TextStyle(
                                color: _getStatusColor(status), // Cor baseada no status
                                fontWeight: FontWeight.bold,
                                fontSize: 18, // Aumentado
                              ),
                            ),
                          ),
                          trailing: Text(
                            formatter.format(totalPedido),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 22.0, // Aumentado
                              color: Colors.deepOrange, // Mudado para cor do tema
                            ),
                          ),
                          onTap: () {
                            // Navegação para a tela de edição
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => EditarPedidoSelecionadoScreen(
                                  pedidoId: pedido['id'],
                                ),
                              ),
                            ).then((_) => _fetchPedidos()); // Recarrega os pedidos ao voltar
                          },
                        ),
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
