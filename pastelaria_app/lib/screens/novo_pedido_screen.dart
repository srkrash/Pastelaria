import 'package:flutter/material.dart';
import 'package:pastelaria_app/screens/add_product_screen.dart';
import 'package:pastelaria_app/screens/add_pastel_screen.dart';

class NovoPedidoScreen extends StatelessWidget {
  const NovoPedidoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Novo Pedido'),
      ),
      body: Column(
        children: [
          // Linha 1: Botões de categoria de produto
          Container(
            color: Colors.grey[200],
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            // Troque o Row por um Column para empilhar os botões verticalmente.
            child: Column(
              // Faz os botões ocuparem toda a largura disponível.
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildCategoryButton(
                  context,
                  text: 'Adicionar Pastel',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const AddPastelScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8.0), // Adiciona um espaçamento entre os botões.
                _buildCategoryButton(
                  context,
                  text: 'Adicionar Bebida',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const AddProductScreen(productType: 'Bebidas'),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8.0), // Adiciona um espaçamento entre os botões.
                _buildCategoryButton(
                  context,
                  text: 'Adicionar Salgado',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const AddProductScreen(productType: 'Salgados'),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          
          // Linha 2: Carrinho de itens selecionados
          Expanded(
            child: Container(
              color: Colors.grey[400],
              child: const Center(
                child: Text('Itens no Pedido', style: TextStyle(fontSize: 20)),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(context),
    );
  }

  // O helper _buildCategoryButton foi ajustado para remover o Expanded.
  Widget _buildCategoryButton(BuildContext context, {required String text, required VoidCallback onPressed}) {
    return ElevatedButton(
      onPressed: onPressed,
      child: Text(text, textAlign: TextAlign.center),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    // ... (código do rodapé com botões de confirmar e cancelar) ...
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                print('Pedido Cancelado!');
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 20),
                side: const BorderSide(color: Colors.red),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Cancelar Pedido', style: TextStyle(fontSize: 18, color: Colors.red)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                print('Pedido Confirmado!');
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Confirmar Pedido', style: TextStyle(fontSize: 18)),
            ),
          ),
        ],
      ),
    );
  }
}