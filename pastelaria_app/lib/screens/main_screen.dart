// lib/screens/main_screen.dart
import 'package:flutter/material.dart';
import 'package:pastelaria_app/screens/pastel_queue_screen.dart'; // Importe a tela da fila de pasteis

// TELAS AINDA NÃO DESENVOLVIDAS (PLACEHOLDERS)
import 'package:pastelaria_app/screens/pedido_screen.dart';
import 'package:pastelaria_app/screens/entrega_screen.dart';


class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0; // Controla qual item do menu está selecionado

  // Lista de widgets (telas) que serão exibidos no corpo do Scaffold
  final List<Widget> _widgetOptions = <Widget>[
    const PedidoScreen(), // Tela 'Fazer Pedido'
    const PastelQueueScreen(), // Tela 'Fila de Produção'
    const EntregaScreen(), // Tela 'Fila de Entrega'
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    // Fecha o drawer após a seleção
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pastelaria App'),
      ),
      // Corpo do aplicativo, exibe a tela selecionada
      body: _widgetOptions.elementAt(_selectedIndex),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            const DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.blue,
              ),
              child: Text(
                'Menu',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.add_shopping_cart),
              title: const Text('Fazer Pedido'),
              selected: _selectedIndex == 0,
              onTap: () => _onItemTapped(0),
            ),
            ListTile(
              leading: const Icon(Icons.kitchen),
              title: const Text('Fila de Produção'),
              selected: _selectedIndex == 1,
              onTap: () => _onItemTapped(1),
            ),
            ListTile(
              leading: const Icon(Icons.delivery_dining),
              title: const Text('Fila de Entrega'),
              selected: _selectedIndex == 2,
              onTap: () => _onItemTapped(2),
            ),
          ],
        ),
      ),
    );
  }
}