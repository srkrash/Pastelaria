import 'package:flutter/material.dart';
import 'package:pastelaria_app/screens/novo_pedido_screen.dart'; // Importe o nome correto da tela
import 'package:pastelaria_app/screens/editar_pedidos_screen.dart';

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
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const NovoPedidoScreen(), // Use o nome correto da classe
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              _buildButton(
                context,
                text: 'Editar Pedido',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const EditarPedidosScreen(), // Use o nome correto da classe
                    ),
                  );
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