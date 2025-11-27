// lib/screens/fila_entrega_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
// Note: O ApiService não é mais usado diretamente para a lista, mas é mantido
// se o método de despacho ainda usá-lo ou se o Provider depender dele.
import '../services/api_service.dart'; 
import '../providers/pedidos_provider.dart'; 

class FilaEntregaScreen extends StatefulWidget {
  const FilaEntregaScreen({super.key});

  @override
  State<FilaEntregaScreen> createState() => _FilaEntregaScreenState();
}

class _FilaEntregaScreenState extends State<FilaEntregaScreen> {
  // 1. Defina a GlobalKey para o AnimatedList.
  // Ela será única para esta instância e será passada ao Provider.
  final GlobalKey<AnimatedListState> _animatedListKeyEntrega = GlobalKey<AnimatedListState>();
  
  // O ApiService só é necessário se a lógica de despacho não for completamente movida para o Provider.
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    // Usa addPostFrameCallback para garantir que o contexto esteja disponível.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<PedidosProvider>(context, listen: false);
      
      // 2. Passe a chave para o Provider
      provider.setListKeyEntrega(_animatedListKeyEntrega);
      
      // 3. Inicie a carga inicial dos dados da fila de entrega
      provider.fetchFilaEntrega();
    });
  }

  // A função de despacho é adaptada para interagir com o Provider e a animação de remoção.
  void _despacharPedido(int pedidoId, int index, PedidosProvider provider) async {
    // Confirmação de despacho
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Despacho'),
        content: Text('Tem certeza que deseja marcar o Pedido #$pedidoId como entregue (FECHADO)?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.red)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Despachar', style: TextStyle(color: Colors.green)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // 4. Lógica de atualização de status (mantida no ApiService para ser robusta)
      final success = await _apiService.updatePedidoStatus(pedidoId, 'fechado');
      
      if (success) {
        // Exibe sucesso
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Pedido #$pedidoId despachado com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
        
        // 5. REMOÇÃO ANIMADA
        // Salva uma cópia dos dados para a animação
        final pedidoRemovido = provider.filaEntrega[index]; 
        
        // 5a. Remove da lista local no Provider (sem notifyListeners)
        provider.removerPedidoEntrega(index); 
        
        // 5b. Anima a remoção usando a chave
        _animatedListKeyEntrega.currentState?.removeItem(
          index,
          (context, animation) => _buildRemovedItemCard(pedidoRemovido, animation),
          duration: const Duration(milliseconds: 500),
        );
      }
    } catch (e) {
      // Exibe erro
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao despachar pedido: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  // Widget que exibe o item sendo removido com animação
  Widget _buildRemovedItemCard(dynamic pedido, Animation<double> animation) {
    final String numeroPedido = pedido['numero_pedido']?.toString() ?? 'N/A';
    return SizeTransition(
      sizeFactor: animation,
      axisAlignment: 0.0,
      child: Card(
        elevation: 4,
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        color: Colors.grey.shade200,
        child: ListTile(
          leading: const Icon(Icons.check_circle, color: Colors.green),
          title: Text('Pedido #$numeroPedido Despachado!', style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: const Text('Removendo da fila de despacho...'),
        ),
      ),
    );
  }

  // Componente para exibir os detalhes dos itens de um pedido (MANTIDO)
  Widget _buildItensDetails(List<dynamic> itens) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: itens.map((item) {
        final String nome = item['produto_nome']?.toString() ?? 'Item';
        final int quantidade = item['quantidade'] as int? ?? 1;
        
        String detalhe = '$quantidade x $nome';
        if (item['observacoes_item'] != null && item['observacoes_item'].isNotEmpty) {
          detalhe += ' (Obs: ${item['observacoes_item']})';
        }
        
        if (item['ingredientes'] != null && item['ingredientes'].isNotEmpty) {
            final List<String> ingredientes = (item['ingredientes'] as List<dynamic>).map((e) => e.toString()).toList();
            detalhe += ' - ${ingredientes.join(', ')}';
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 4.0),
          child: Text(
            detalhe,
            style: const TextStyle(fontSize: 18, color: Color.fromARGB(255, 31, 41, 46)),
          ),
        );
      }).toList(),
    );
  }

  // Widget para construir o Card do Pedido (Adaptado para AnimatedList)
  Widget _buildPedidoCard({
    required dynamic pedido, 
    required int index, 
    required PedidosProvider provider,
    required Animation<double> animation, // Parâmetro de animação
  }) {
    final formatter = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final int pedidoId = int.tryParse(pedido['pedido_id']?.toString() ?? '0') ?? 0;
    final String numeroPedido = pedido['numero_pedido']?.toString() ?? 'N/A';
    final double totalPedido = double.tryParse(pedido['total_pedido']?.toString() ?? '0.0') ?? 0.0;
    final String observacao = pedido['observacoes']?.toString() ?? '';
    final List<dynamic> itens = pedido['itens'] ?? [];
    
    // Lógica de Parsing do Tipo de Pedido
    String tipoPedido = 'CONSUMO'; // Default
    String observacaoLimpa = observacao;
    Color cardColor = Colors.orange.shade50;
    Color borderColor = Colors.orange.shade200;
    Color headerColor = Colors.deepOrange;

    if (observacao.startsWith('[Viagem]')) {
        tipoPedido = 'VIAGEM';
        observacaoLimpa = observacao.substring(8).trim();
        cardColor = Colors.blue.shade50;
        borderColor = Colors.blue.shade200;
        headerColor = Colors.blue.shade800;
    } else if (observacao.startsWith('[Consumo]')) {
        tipoPedido = 'CONSUMO';
        observacaoLimpa = observacao.substring(9).trim();
        cardColor = Colors.orange.shade50;
        borderColor = Colors.orange.shade200;
        headerColor = Colors.deepOrange;
    }

    // 6. Aplica a animação de SLIDE no Card
    return SlideTransition(
        position: Tween<Offset>(
            // Inserção animada: o item entra da direita
            begin: const Offset(1, 0), 
            end: Offset.zero,
        ).animate(animation),
        child: Card(
          elevation: 4,
          margin: const EdgeInsets.symmetric(vertical: 8.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: BorderSide(color: borderColor, width: 2),
          ),
          color: cardColor,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: headerColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: headerColor.withOpacity(0.5)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '#$numeroPedido',
                                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: headerColor),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  tipoPedido,
                                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: headerColor),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      formatter.format(totalPedido),
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green),
                    ),
                  ],
                ),
                const Divider(),
                
                const Text('Conteúdo:', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                _buildItensDetails(itens),

                if (observacaoLimpa.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade100,
                      borderRadius: BorderRadius.circular(8)
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, size: 24, color: Colors.amber),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Obs: $observacaoLimpa', 
                            style: TextStyle(fontSize: 18, fontStyle: FontStyle.italic, color: Colors.amber.shade900)
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 15),

                // Botão de Ação
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    // Chama a função de despacho com os novos parâmetros
                    onPressed: () => _despacharPedido(pedidoId, index, provider),
                    icon: const Icon(Icons.delivery_dining, size: 28),
                    label: const Text('Marcar como Despachado (Finalizar)', style: TextStyle(fontSize: 20)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 7. Usa o Consumer para ouvir as mudanças na fila do Provider
    return Consumer<PedidosProvider>(
      builder: (context, provider, child) {
        final List<dynamic> fila = provider.filaEntrega;
        
        return Scaffold(
          appBar: AppBar(
            title: const Text('Fila de Pedidos para Despacho'),
            backgroundColor: Colors.deepOrange,
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                // Chama o método de recarga do Provider
                onPressed: provider.fetchFilaEntrega, 
              )
            ],
          ),
          body: fila.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_outline, size: 80, color: Colors.green),
                      SizedBox(height: 16),
                      Text('Nenhum pedido na fila de despacho.', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
                      Text('Tudo em dia!', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : AnimatedList(
                  // 8. Usa a GlobalKey aqui para controlar as animações
                  key: _animatedListKeyEntrega,
                  padding: const EdgeInsets.all(12.0),
                  // O initialItemCount deve ser o tamanho atual da lista
                  initialItemCount: fila.length, 
                  itemBuilder: (context, index, animation) {
                    final pedido = fila[index];
                    
                    // 9. Usa o método de construção de card adaptado
                    return _buildPedidoCard(
                      pedido: pedido,
                      index: index,
                      provider: provider,
                      animation: animation,
                    );
                  },
                ),
        );
      },
    );
  }
}