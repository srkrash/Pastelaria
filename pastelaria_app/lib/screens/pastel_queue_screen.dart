// lib/screens/pastel_queue_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/pedidos_provider.dart';
import '../models/item_pedido.dart';

class PastelQueueScreen extends StatefulWidget {
  const PastelQueueScreen({super.key});

  @override
  State<PastelQueueScreen> createState() => _PastelQueueScreenState();
}

class _PastelQueueScreenState extends State<PastelQueueScreen> {
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Provider.of<PedidosProvider>(context, listen: false).prepareFilaPastel();
      // Anima a entrada dos itens iniciais
      final pedidosProvider = Provider.of<PedidosProvider>(context, listen: false);
      for(int i = 0; i < pedidosProvider.filaPastel.length; i++) {
        _listKey.currentState?.insertItem(i, duration: const Duration(milliseconds: 500));
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _handleKey(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.keyL) {
        Provider.of<PedidosProvider>(context, listen: false).avancarFila(_listKey);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fila de Pastéis'),
      ),
      body: KeyboardListener(
        focusNode: _focusNode,
        onKeyEvent: _handleKey,
        autofocus: true,
        child: GestureDetector(
          onTap: () {
            FocusScope.of(context).requestFocus(_focusNode);
          },
          child: Consumer<PedidosProvider>(
            builder: (context, pedidosProvider, child) {
              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: AnimatedList(
                  key: _listKey,
                  initialItemCount: pedidosProvider.filaPastel.length,
                  scrollDirection: Axis.horizontal,
                  itemBuilder: (context, index, animation) {
                    final item = pedidosProvider.filaPastel[index];
                    return SizeTransition( // Anima a entrada do item
                      sizeFactor: animation,
                      axis: Axis.horizontal,
                      child: SizedBox(
                        width: MediaQuery.of(context).size.width / 4, // Exibe 4 cards na tela
                        child: _buildPastelCard(item),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPastelCard(ItemPedido item) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Pedido #${item.id}',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                'Ingredientes: ${item.ingredientes.join(', ')}',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}