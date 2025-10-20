import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
// Note: Assumindo que o ItemPedido virá como um Map dentro da lista 'itens'

class EditarPedidoSelecionadoScreen extends StatefulWidget {
  final int pedidoId;

  const EditarPedidoSelecionadoScreen({super.key, required this.pedidoId});

  @override
  State<EditarPedidoSelecionadoScreen> createState() => _EditarPedidoSelecionadoScreenState();
}

class _EditarPedidoSelecionadoScreenState extends State<EditarPedidoSelecionadoScreen> {
  final ApiService _apiService = ApiService();
  // Alteramos o tipo para Future<Map<String, dynamic>> pois o API service retorna um dynamic 
  // que esperamos que seja um Map<String, dynamic> após o decode do JSON.
  late Future<Map<String, dynamic>> _pedidoFuture;

  @override
  void initState() {
    super.initState();
    _fetchPedidoDetails();
  }

  void _fetchPedidoDetails() {
    setState(() {
      // **Integração com a função da API real:**
      _pedidoFuture = _apiService.getPedidoPorId(widget.pedidoId).then((data) {
        // Garantindo que a resposta seja tratada como Map<String, dynamic>
        // ignore: unnecessary_type_check
        if (data is Map<String, dynamic>) {
          return data;
        } else {
          // Se a API retornar null ou um tipo inesperado, tratamos como um erro
          throw Exception('Formato de dados do pedido inválido.');
        }
      });
    });
  }

  // Helper para obter a cor do status (mantendo consistência com EditarPedidosScreen)
  Color _getStatusColor(String status) {
    switch (status) {
      case 'aberto':
      case 'aguardando': // Adicionado status de item
        return Colors.amber.shade700;
      case 'fechado':
      case 'entregue': // Adicionado status de item (exemplo)
        return Colors.green.shade700;
      case 'cancelado':
        return Colors.red.shade700;
      default:
        return Colors.blueGrey;
    }
  }

  // Helper para obter o texto formatado do status (mantendo consistência com EditarPedidosScreen)
  String _getStatusText(String status) {
    switch (status) {
      case 'aberto':
        return 'Em Aberto';
      case 'fechado':
        return 'Finalizado';
      case 'cancelado':
        return 'Cancelado';
      case 'aguardando':
        return 'Aguardando Produção';
      default:
        return status[0].toUpperCase() + status.substring(1); // Capitaliza o primeiro caractere para outros status
    }
  }
  
  // Lógica para atualizar o status do pedido
  void _updateStatus(int pedidoId, String newStatus) async {
    // **TO DO: Implementar a chamada à API para atualizar o status aqui**
    // Exemplo: final success = await _apiService.updatePedidoStatus(pedidoId, newStatus);
  final bool success = await _apiService.updatePedidoStatus(pedidoId, newStatus);
    // Atualiza a UI após a simulação (ou sucesso da API)
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Pedido #$pedidoId atualizado para ${newStatus.toUpperCase()}!')),
      );
      Navigator.of(context).pop(true); 
    }
    else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Falha ao atualizar o pedido.')),
      );
    }
    
    // Volta para a tela anterior, ativando a recarga em EditarPedidosScreen
  }

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return Scaffold(
      appBar: AppBar(
        title: Text('Detalhes do Pedido #${widget.pedidoId}'),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
      ),
      // FloatingActionButton foi removido.
      body: FutureBuilder<Map<String, dynamic>>(
        future: _pedidoFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            // Se houver erro, exibe a mensagem de erro da API
            return Center(child: Text('Erro ao carregar detalhes do pedido: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Detalhes do pedido não encontrados.'));
          }

          final pedido = snapshot.data!;
          final String status = pedido['status']?.toString() ?? 'desconhecido'; 
          final double totalPedido = double.tryParse(pedido['total_pedido']?.toString() ?? '0.0') ?? 0.0;
          final List<dynamic> itens = pedido['itens'] ?? [];
          // Usando 'observacoes' conforme o endpoint do Flask
          final String observacao = pedido['observacoes']?.toString() ?? ''; 

          return Column(
            children: [
              // HEADER: Status e Total
              Container(
                padding: const EdgeInsets.all(16.0),
                // Cor de fundo levemente amarela para destaque, seguindo o tema pastel
                color: Colors.amber.shade50, 
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Status Atual:', style: TextStyle(fontSize: 14, color: Colors.blueGrey)),
                        Text(
                          _getStatusText(status),
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: _getStatusColor(status),
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Total do Pedido:', style: TextStyle(fontSize: 14, color: Colors.blueGrey)),
                        Text(
                          formatter.format(totalPedido),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepOrange,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Observações do Pedido (se houver)
              if (observacao.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.blueGrey, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Obs. Pedido: $observacao',
                          style: TextStyle(fontStyle: FontStyle.italic, color: Colors.blueGrey.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
                
              const Divider(height: 1),
              
              const Padding(
                padding: EdgeInsets.all(12.0),
                child: Text('Itens do Pedido:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),

              // Lista de Itens
              Expanded(
                child: ListView.builder(
                  itemCount: itens.length,
                  itemBuilder: (context, index) {
                    final item = itens[index];
                    final String produtoNome = item['produto_nome']?.toString() ?? 'Produto Desconhecido'; 
                    final int quantidade = item['quantidade'] as int? ?? 0;
                    
                    // Utilizando as novas chaves do endpoint:
                    final double precoUnitario = double.tryParse(item['preco_unitario']?.toString() ?? '0.0') ?? 0.0;
                    final double subtotal = double.tryParse(item['subtotal']?.toString() ?? '0.0') ?? 0.0; 
                    final List<String> ingredientes = (item['ingredientes'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
                    final String observacaoItem = item['observacoes_item']?.toString() ?? '';
                    final String statusItem = item['status_item']?.toString() ?? 'aguardando';

                    String subtitleText = 'Preço Unit.: ${formatter.format(precoUnitario)}';
                    if (ingredientes.isNotEmpty) {
                        subtitleText += '\nIngredientes: ${ingredientes.join(', ')}';
                    }
                    if (observacaoItem.isNotEmpty) {
                        subtitleText += '\nObs. Item: $observacaoItem';
                    }
                    
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.deepOrange.shade100,
                        child: Text('${quantidade}x', style: const TextStyle(color: Colors.deepOrange)),
                      ),
                      title: Text(produtoNome, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(subtitleText, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                          const SizedBox(height: 4),
                          // Exibe o status individual do item
                          Text(
                            _getStatusText(statusItem),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _getStatusColor(statusItem),
                            ),
                          ),
                        ],
                      ),
                      trailing: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Subtotal:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          Text(
                            formatter.format(subtotal), 
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
                          ),
                        ],
                      ),
                      isThreeLine: ingredientes.isNotEmpty || observacaoItem.isNotEmpty,
                    );
                  },
                ),
              ),

              // FOOTER: Botões de Ação (Apenas se o status for 'aberto')
              if (status == 'aberto')
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      // Botão Cancelar
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _updateStatus(pedido['id'], 'cancelado'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('Cancelar Pedido', style: TextStyle(fontSize: 18)),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Botão Finalizar
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _updateStatus(pedido['id'], 'fechado'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('Finalizar Pedido', style: TextStyle(fontSize: 18)),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
