import 'package:flutter/material.dart';
import 'package:pastelaria_app/screens/novo_pedido_screen.dart'; // Importe a nova tela

class PedidoScreen extends StatelessWidget {
  const PedidoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Realizar Pedido'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildButton(
                context,
                text: 'Novo Pedido',
                onPressed: () {
                  // Ação para ir para a tela de novo pedido
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const NovoPedidoScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              _buildButton(
                context,
                text: 'Editar Pedido',
                onPressed: () {
                  // Ação para ir para a tela de edição de pedido
                  print('Editar Pedido pressionado!');
                  // TODO: Implementar navegação para a tela de editar pedido
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildButton(BuildContext context, {required String text, required VoidCallback onPressed}) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      onPressed: onPressed,
      child: Text(
        text,
        style: const TextStyle(fontSize: 24),
      ),
    );
  }
}