import 'package:flutter/material.dart';
import 'package:pastelaria_app/screens/pastel_queue_screen.dart';
import 'package:pastelaria_app/screens/pedido_screen.dart';
import 'package:pastelaria_app/screens/fila_entrega_screen.dart';
import 'package:pastelaria_app/screens/config_screen.dart';
import 'package:pastelaria_app/screens/log_screen.dart';
import '../services/app_settings.dart';

class MainScreen extends StatefulWidget {
  final String initialRole;
  const MainScreen({super.key, this.initialRole = 'pedido'});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialRole == 'cozinha'
        ? 1
        : widget.initialRole == 'entrega'
            ? 2
            : 0;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final settings = await AppSettings.load();
      if (!mounted || settings.configured) return;
      await _configure();
    });
  }

  Future<void> _configure() async {
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => const ConfigScreen()));
    final settings = await AppSettings.load();
    if (!mounted) return;
    setState(() {
      _selectedIndex = settings.role == 'cozinha'
          ? 1
          : settings.role == 'entrega'
              ? 2
              : 0;
    });
  }

  final List<Widget> _widgetOptions = <Widget>[
    const PedidoScreen(),
    const PastelQueueScreen(),
    const FilaEntregaScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pastelaria App'),
        backgroundColor: Colors.amber,
      ),
      body: _widgetOptions.elementAt(_selectedIndex),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.amber),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Menu Principal',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Navegação',
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading:
                  const Icon(Icons.add_shopping_cart, color: Colors.blueGrey),
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
            ListTile(
              leading: const Icon(Icons.settings, color: Colors.blueGrey),
              title: const Text('Configurações'),
              onTap: () {
                Navigator.pop(context);
                _configure();
              },
            ),
            ListTile(
              leading: const Icon(Icons.bug_report, color: Colors.redAccent),
              title: const Text('Logs do Sistema'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const LogScreen()),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.info_outline, color: Colors.grey),
              title: const Text('Sobre'),
              onTap: () {
                Navigator.pop(context);
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Pastelaria App'),
                    content: const Text(
                        'Pastelaria Gaúcha\nServidor local no tablet\nVersão 2.0.0 em validação'),
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
