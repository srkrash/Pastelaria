// lib/screens/new_order_screen.dart
import 'package:flutter/material.dart';

class NovoPedidoScreen extends StatelessWidget {
  const NovoPedidoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Novo Pedido'),
      ),
      body: Center(
        child: Text(
          'Tela de novo pedido em construção...',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}