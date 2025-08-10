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
  final FocusNode _focusNode = FocusNode();
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();

@override
void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final pedidosProvider = Provider.of<PedidosProvider>(context, listen: false);
      pedidosProvider.setListKey(_listKey);
      await pedidosProvider.prepareFilaPastel();

      // ESTA É A FUNÇÃO QUE FALTAVA PARA EXIBIR OS CARDS INICIAIS
      // Anima a entrada de cada item na lista, um por um
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
      if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        // Agora, o método avancarFila não precisa mais receber a chave
        Provider.of<PedidosProvider>(context, listen: false).avancarFila();
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
                    return SizeTransition(
                      sizeFactor: animation,
                      axis: Axis.horizontal,
                      child: SizedBox(
                        width: MediaQuery.of(context).size.width / 4,
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
                'Item #${item.id}',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                'Ingredientes: \n${item.ingredientes.join('\n')}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}