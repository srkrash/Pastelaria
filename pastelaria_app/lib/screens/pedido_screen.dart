import 'package:flutter/material.dart';
import 'package:pastelaria_app/screens/novo_pedido_screen.dart'; // Importe o nome correto da tela
import 'package:pastelaria_app/screens/editar_pedidos_screen.dart';

class PedidoScreen extends StatelessWidget {
  const PedidoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Realizar Pedido (PDV)'),
        backgroundColor: Colors.amber, // Cor de destaque para o PDV
      ),
      body: Center(
        child: Container(
          // Define uma largura máxima para tablets para que os botões não fiquem gigantes
          constraints: const BoxConstraints(maxWidth: 600),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildButton(
                  context,
                  text: 'Novo Pedido',
                  icon: Icons.add_shopping_cart,
                  color: Colors.deepOrange, // Destaque para a ação principal
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const NovoPedidoScreen(), // Navega para a tela de criação
                      ),
                    );
                  },
                ),
                const SizedBox(height: 32),
                _buildButton(
                  context,
                  text: 'Editar Pedido',
                  icon: Icons.edit_note,
                  color: Colors.blueGrey, // Cor secundária
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const EditarPedidosScreen(), // Navega para a tela de edição
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildButton(BuildContext context, {required String text, required IconData icon, required Color color, required VoidCallback onPressed}) {
    return ElevatedButton.icon(
      icon: Icon(icon, size: 36),
      label: Text(
        text,
        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
      ),
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        elevation: 8,
      ),
      onPressed: onPressed,
    );
  }
}
