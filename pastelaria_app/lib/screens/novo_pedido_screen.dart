import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:pastelaria_app/providers/pedidos_provider.dart';
import 'package:pastelaria_app/screens/add_pastel_screen.dart';
import 'package:pastelaria_app/screens/add_product_screen.dart';
import 'package:pastelaria_app/models/item_pedido.dart';
import 'package:pastelaria_app/services/api_service.dart';

class NovoPedidoScreen extends StatefulWidget {
  const NovoPedidoScreen({super.key});

  @override
  State<NovoPedidoScreen> createState() => _NovoPedidoScreenState();
}

class _NovoPedidoScreenState extends State<NovoPedidoScreen> {
  bool _isLoading = false;
  final ApiService _apiService = ApiService();

  // Método para navegar e adicionar itens do pastel
  void _navigateAndAddItem(BuildContext context) async {
    final PedidosProvider pedidosProvider =
        Provider.of<PedidosProvider>(context, listen: false);

    final resultado = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AddPastelScreen(),
      ),
    );

    if (resultado != null) {
      final quantidade = resultado['quantidade'] as int;
      final ingredientes = resultado['ingredientes'] as List<String>;
      final observacoes = resultado['observacoesItem'] as String;

      String produtoNome = 'Pastel';

      final novoItem = ItemPedido(
        id: 0,
        quantidade: quantidade,
        produtoNome: produtoNome,
        statusItem: 'aguardando',
        preco: 0.0,
        ingredientes: ingredientes,
        observacoesItem: observacoes,
      );

      pedidosProvider.adicionarItem(novoItem);
    }
  }

// lib/screens/novo_pedido_screen.dart
// ... (imports e classe NovoPedidoScreenState) ...

// Função auxiliar para calcular o preço de um pastel específico.
double _calcularPrecoPastel(ItemPedido item) {
  final List<String> ingredientesGratuitos = [
    'Cebola',
    'Cebolinha',
    'Orégano'
  ];

  if (item.ingredientes.length == 1 && item.ingredientes.first == 'Pizza') {
    return 15.00 * item.quantidade;
  } else if (item.ingredientes.length == 1 && item.ingredientes.first == 'Misto') {
    return 25.00 * item.quantidade;
  } else {
    // Lógica para pastéis com ingredientes extras.
    final List<String> ingredientesPagos = item.ingredientes
        .where((ing) => !ingredientesGratuitos.contains(ing))
        .toList();

    double precoBase = 12.00;
    int numIngredientesPagos = ingredientesPagos.length;

    if (numIngredientesPagos > 2) {
      precoBase += (numIngredientesPagos - 2) * 3.00;
    }
    return precoBase * item.quantidade;
  }
}

// A função principal de cálculo do subtotal.
double _calcularSubtotal() {
  double total = 0.0;
  for (var item in Provider.of<PedidosProvider>(context).itensPedidoAtual) {
    if (item.produtoNome.startsWith('Pastel')) {
      // Delega o cálculo do preço do pastel para a função auxiliar.
      total += _calcularPrecoPastel(item);
    } else {
      // Usa o preço direto para salgados e bebidas.
      total += (item.preco) * item.quantidade;
    }
  }
  return total;
}

 void _navigateAndAddProducts(BuildContext context, String productType) async {
    final pedidosProvider = Provider.of<PedidosProvider>(context, listen: false);

    final resultado = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AddProductScreen(productType: productType),
      ),
    );

    if (resultado != null && resultado is List<ItemPedido>) {
      for (var item in resultado) {
        pedidosProvider.adicionarItem(item);
      }
    }
  }
  // Função para confirmar o pedido usando o ApiService
  Future<void> _confirmarPedido(PedidosProvider pedidosProvider) async {
    if (pedidosProvider.itensPedidoAtual.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Adicione pelo menos um item para confirmar o pedido.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final List<Map<String, dynamic>> itensData =
        pedidosProvider.itensPedidoAtual.map((item) {
      return {
        'produto_nome': item.produtoNome,
        'quantidade': item.quantidade,
        'ingredientes': item.ingredientes
            .map((ing) => {'nome': ing, 'quantidade': 1})
            .toList(),
        'observacoes_item': item.observacoesItem,
      };
    }).toList();

    final pedidoPayload = {
      'observacoes_pedido':
          '', // Adicione a observação do pedido se for necessário
      'itens': itensData,
    };

    try {
      final response =
          await _apiService.inserirPedido('pedidos', pedidoPayload);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Pedido #${response['numero_pedido']} confirmado com sucesso!')),
      );

      pedidosProvider.limparPedido();
      // Opcional: Navegar para outra tela ou fechar a atual
      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao confirmar pedido: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pedidosProvider = Provider.of<PedidosProvider>(context);
    final bool canConfirm = pedidosProvider.itensPedidoAtual.isNotEmpty && !_isLoading;

    // NOVO: Calcula o subtotal e formata
    final double subtotal = _calcularSubtotal();
    final String subtotalFormatado = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(subtotal);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Novo Pedido'),
      ),
      body: Column(
        children: [
          Container(
            color: Colors.grey[200],
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildCategoryButton(
                  context,
                  text: 'Adicionar Pastel',
                  onPressed: () => _navigateAndAddItem(context),
                ),
                const SizedBox(height: 8.0),
                _buildCategoryButton(
                  context,
                  text: 'Adicionar Bebida',
                  onPressed: () => _navigateAndAddProducts(context, 'bebida'), // Chama a tela genérica
                ),
                const SizedBox(height: 8.0),
                _buildCategoryButton(
                  context,
                  text: 'Adicionar Salgado',
                  onPressed: () => _navigateAndAddProducts(context, 'salgado'), // Chama a tela genérica
                ),
              ],
            ),
          ),
          
          Expanded(
            child: Container(
              color: const Color.fromARGB(235, 255, 245, 237),
              child: pedidosProvider.itensPedidoAtual.isEmpty
                  ? const Center(
                      child: Text('Nenhum item adicionado', style: TextStyle(fontSize: 18)),
                    )
                  : ListView.builder(
                      itemCount: pedidosProvider.itensPedidoAtual.length,
                      itemBuilder: (context, index) {
                        final item = pedidosProvider.itensPedidoAtual[index];
                        return ListTile(
                          title: Text('${item.quantidade} x ${item.produtoNome}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: item.ingredientes.isEmpty 
                              ? null 
                              : Text('- ${item.ingredientes.join(', ')}', style: const TextStyle(fontStyle: FontStyle.normal, fontSize: 18)),
                          trailing: IconButton(
                            icon: const Icon(Icons.remove_circle, color: Colors.red),
                            onPressed: () {
                              pedidosProvider.removerItem(item);
                            },
                          ),
                        );
                      },
                    ),
            ),
          ),
          
          // NOVO: Linha para mostrar o subtotal
          Container(
            padding: const EdgeInsets.all(16.0),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Subtotal:', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                Text(subtotalFormatado, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              ],
            ),
          ),

        ],
      ),
      bottomNavigationBar: _buildBottomBar(context, pedidosProvider, canConfirm),
    );
  }

  // ... (métodos _build existentes) ...
  Widget _buildCategoryButton(BuildContext context,
      {required String text, required VoidCallback onPressed}) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 24)),
    );
  }

  Widget _buildBottomBar(
      BuildContext context, PedidosProvider pedidosProvider, bool canConfirm) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _isLoading
                  ? null
                  : () {
                      pedidosProvider.limparPedido();
                    },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 20),
                side: const BorderSide(color: Colors.red),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Cancelar Pedido',
                  style: TextStyle(fontSize: 18, color: Colors.red)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed:
                  canConfirm ? () => _confirmarPedido(pedidosProvider) : null,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 20),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Confirmar Pedido',
                      style: TextStyle(fontSize: 18)),
            ),
          ),
        ],
      ),
    );
  }
}
