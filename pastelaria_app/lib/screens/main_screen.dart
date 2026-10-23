import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/pedidos_provider.dart';
import '../services/app_settings.dart';
import '../ui/app_ui.dart';
import 'pastel_queue_screen.dart';
import 'pedido_screen.dart';
import 'fila_entrega_screen.dart';
import 'config_screen.dart';
import 'log_screen.dart';

class MainScreen extends StatefulWidget {
  final String initialRole;
  const MainScreen({super.key, this.initialRole = 'pedido'});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selected = 0;
  static const _labels = ['Pedidos', 'Cozinha', 'Entrega'];
  static const _icons = [
    Icons.point_of_sale_outlined,
    Icons.soup_kitchen_outlined,
    Icons.shopping_bag_outlined
  ];
  static const _pages = [
    PedidoScreen(),
    PastelQueueScreen(),
    FilaEntregaScreen()
  ];
  @override
  void initState() {
    super.initState();
    _selected = _index(widget.initialRole);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final settings = await AppSettings.load();
      if (!mounted || settings.configured) return;
      await _configure();
    });
  }

  int _index(String role) => role == 'cozinha'
      ? 1
      : role == 'entrega'
          ? 2
          : 0;
  Future<void> _configure() async {
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => const ConfigScreen()));
    final settings = await AppSettings.load();
    if (mounted) setState(() => _selected = _index(settings.role));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PedidosProvider>();
    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= 850;
      final status = Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
        child: Row(children: [
          const Icon(Icons.storefront, size: 21, color: brand),
          const SizedBox(width: 8),
          const Expanded(
              child: Text('PASTELARIA GAÚCHA',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                      fontSize: 13))),
          StatusPill(
              p.error != null
                  ? 'Sem conexão'
                  : p.lastSync == null
                      ? 'Conectando'
                      : 'Sincronizado',
              color: p.error != null ? brand : success,
              icon: p.error != null
                  ? Icons.wifi_off
                  : Icons.check_circle_outline),
          IconButton(
              tooltip: 'Configurações',
              onPressed: _configure,
              icon: const Icon(Icons.settings_outlined)),
          PopupMenuButton<String>(
              tooltip: 'Mais opções',
              onSelected: (v) {
                if (v == 'logs') {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const LogScreen()));
                } else {
                  showAboutDialog(
                      context: context,
                      applicationName: 'Pastelaria Gaúcha',
                      applicationVersion: '2.1.0 · em validação');
                }
              },
              itemBuilder: (_) => const [
                    PopupMenuItem(
                        value: 'logs', child: Text('Diagnóstico e logs')),
                    PopupMenuItem(
                        value: 'about', child: Text('Sobre o aplicativo'))
                  ]),
        ]),
      );
      return Scaffold(
        body: SafeArea(
            child: Row(children: [
          if (wide)
            NavigationRail(
              backgroundColor: Colors.white,
              selectedIndex: _selected,
              minWidth: 100,
              labelType: NavigationRailLabelType.all,
              groupAlignment: -.6,
              leading: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Icon(Icons.local_dining, color: brand, size: 32)),
              onDestinationSelected: (i) => setState(() => _selected = i),
              destinations: List.generate(
                  3,
                  (i) => NavigationRailDestination(
                      icon: Icon(_icons[i]), label: Text(_labels[i]))),
            ),
          Expanded(
              child: Column(
                  children: [status, Expanded(child: _pages[_selected])])),
        ])),
        bottomNavigationBar: wide
            ? null
            : NavigationBar(
                selectedIndex: _selected,
                onDestinationSelected: (i) => setState(() => _selected = i),
                destinations: List.generate(
                    3,
                    (i) => NavigationDestination(
                        icon: Icon(_icons[i]), label: _labels[i]))),
      );
    });
  }
}
