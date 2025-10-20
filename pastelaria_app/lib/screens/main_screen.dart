import 'package:flutter/material.dart';
import 'package:pastelaria_app/screens/pastel_queue_screen.dart';
import 'package:pastelaria_app/screens/pedido_screen.dart';
import 'package:pastelaria_app/screens/fila_entrega_screen.dart';


class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0; // Controla qual item do menu está selecionado

  // Lista de widgets (telas) que serão exibidos no corpo do Scaffold
  final List<Widget> _widgetOptions = <Widget>[
    const PedidoScreen(), // Tela 'Fazer Pedido' (PDV)
    const PastelQueueScreen(), // Tela 'Fila de Produção' (Cozinha)
    const FilaEntregaScreen(), // Tela 'Fila de Entrega' (Expedição)
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
        backgroundColor: Colors.amber, // Cor temática
      ),
      // Corpo do aplicativo, exibe a tela selecionada
      body: _widgetOptions.elementAt(_selectedIndex),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            const DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.amber, // Cor temática
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Menu Principal',
                    style: TextStyle(
                      color: Colors.black, // Alterado para preto para alto contraste
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Navegação',
                    style: TextStyle(
                      color: Colors.black54, // Alterado para um cinza escuro para contraste
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.add_shopping_cart, color: Colors.blueGrey),
              title: const Text('Fazer Pedido (PDV)'),
              selected: _selectedIndex == 0,
              onTap: () => _onItemTapped(0),
            ),
            ListTile(
              leading: const Icon(Icons.kitchen, color: Colors.orange),
              title: const Text('Fila de Produção (Cozinha)'),
              selected: _selectedIndex == 1,
              onTap: () => _onItemTapped(1),
            ),
            ListTile(
              leading: const Icon(Icons.delivery_dining, color: Colors.green),
              title: const Text('Fila de Entrega'),
              selected: _selectedIndex == 2,
              onTap: () => _onItemTapped(2),
            ),
            const Divider(),
            // Adicionando um espaço para futuras opções, como relatórios
            ListTile(
              leading: const Icon(Icons.info_outline, color: Colors.grey),
              title: const Text('Sobre'),
              onTap: () {
                // Fechar o drawer
                Navigator.pop(context); 
                // Exibir um diálogo simples ou navegar para uma tela de informações
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Pastelaria App'),
                    content: const Text('Sistema de gestão de pedidos e produção. V1.0'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
