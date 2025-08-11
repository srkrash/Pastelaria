// Tela genérica para adicionar bebidas e salgados
import 'package:flutter/material.dart';

class AddProductScreen extends StatelessWidget {
  final String productType;

  const AddProductScreen({super.key, required this.productType});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Adicionar $productType'),
      ),
      body: Center(
        child: Text(
          'Lista de $productType em construção...',
          style: const TextStyle(fontSize: 24),
        ),
      ),
      bottomNavigationBar: _buildBottomBar(context),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          // Botão Cancelar
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Volta para a tela anterior
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 20),
                side: const BorderSide(color: Colors.red),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Cancelar', style: TextStyle(fontSize: 18, color: Colors.red)),
            ),
          ),
          
          const SizedBox(width: 16),
          
          // Botão Adicionar
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                // TODO: Adicionar lógica para adicionar itens ao pedido
                print('Adicionado itens de $productType ao pedido!');
                Navigator.of(context).pop(); // Volta para a tela anterior
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Adicionar', style: TextStyle(fontSize: 18)),
            ),
          ),
        ],
      ),
    );
  }
}