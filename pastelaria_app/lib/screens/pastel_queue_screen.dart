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
  // FocusNode é essencial para capturar eventos de teclado (como a tecla 'Seta para a Esquerda')
  final FocusNode _focusNode = FocusNode();
  // GlobalKey é a ponte entre a UI (AnimatedList) e o Provider (para inserção/remoção animada)
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();

  @override
  void initState() {
    super.initState();
    // Usa addPostFrameCallback para garantir que o contexto do Provider esteja disponível
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final pedidosProvider = Provider.of<PedidosProvider>(context, listen: false);
      
      // 1. Passa a chave para o Provider para que ele possa animar as inserções via SocketIO
      pedidosProvider.setListKey(_listKey);
      
      // 2. Carrega a fila inicial (itens 'aguardando' e 'em_producao')
      await pedidosProvider.prepareFilaPastel();

      // 3. Anima a entrada dos itens iniciais.
      // Isso é necessário porque AnimatedList só mostra o que é INSERIDO após a montagem.
      for(int i = 0; i < pedidosProvider.filaPastel.length; i++) {
        // Usa `Future.delayed` para criar um efeito de cascata mais suave
        await Future.delayed(const Duration(milliseconds: 100));
        _listKey.currentState?.insertItem(i, duration: const Duration(milliseconds: 500));
      }

      // Garante que o foco seja setado após a construção inicial
      FocusScope.of(context).requestFocus(_focusNode);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  // Lógica para capturar a tecla de atalho (Seta Esquerda) para avançar na fila
  void _handleKey(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        // Chama o método do provider para remover o primeiro item e atualizar o status
        Provider.of<PedidosProvider>(context, listen: false).avancarFila();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fila de Pastéis (KDS)'),
        backgroundColor: Colors.orange, // Cor de destaque para a área de produção
        actions: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios),
            tooltip: 'Avançar Fila (Seta Esquerda)',
            // Permite que o usuário clique no botão, além de usar o atalho de teclado
            onPressed: () => Provider.of<PedidosProvider>(context, listen: false).avancarFila(),
          ),
          const SizedBox(width: 16),
        ],
      ),
      // KeyboardListener para captura de eventos de teclado
      body: KeyboardListener(
        focusNode: _focusNode,
        onKeyEvent: _handleKey,
        autofocus: true, // Garante que a tela tente focar imediatamente
        child: GestureDetector(
          // Permite que o usuário toque em qualquer lugar para re-focar e usar a tecla de atalho
          onTap: () {
            FocusScope.of(context).requestFocus(_focusNode);
          },
          child: Consumer<PedidosProvider>(
            builder: (context, pedidosProvider, child) {
              // ----------------------------------------------------
              // Se a lista estiver vazia, exibe uma mensagem centralizada
              if (pedidosProvider.filaPastel.isEmpty && pedidosProvider.filaPastel.length == 0) {
                 return const Center(
                   child: Column(
                     mainAxisAlignment: MainAxisAlignment.center,
                     children: [
                       Icon(Icons.check_circle_outline, size: 80, color: Colors.green),
                       SizedBox(height: 16),
                       Text(
                         'Fila vazia! Hora do café!',
                         style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: Colors.green),
                       ),
                     ],
                   ),
                 );
              }
              // ----------------------------------------------------

              // A AnimatedList usa a lista do Provider como fonte de dados
              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: AnimatedList(
                  key: _listKey,
                  // O initialItemCount é importante, mas o AnimatedList gerencia o tamanho real
                  initialItemCount: pedidosProvider.filaPastel.length, 
                  scrollDirection: Axis.horizontal,
                  itemBuilder: (context, index, animation) {
                    // O AnimatedList tenta construir para o índice. É vital checar o limite aqui.
                    if (index >= pedidosProvider.filaPastel.length) {
                      return const SizedBox.shrink(); 
                    }
                    
                    final item = pedidosProvider.filaPastel[index];
                    return SizeTransition(
                      sizeFactor: animation,
                      axis: Axis.horizontal,
                      child: SizedBox(
                        // Em modo paisagem, divide a tela para caber 3-4 cards
                        width: MediaQuery.of(context).size.width / 4, 
                        height: double.infinity, // Ocupa a altura total disponível
                        child: _buildPastelCard(item, index),
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

  // Card que exibe os detalhes de um item da fila
  Widget _buildPastelCard(ItemPedido item, int index) {
    // Define cores e ícones baseados no status e na posição na fila
    Color cardColor = Colors.white;
    String statusText = item.statusItem;

    if (item.statusItem == 'em_producao' || index == 0) {
      cardColor = Colors.yellow.shade100; // Destaque para o item sendo preparado
      statusText = 'EM PREPARAÇÃO';
    } else if (item.statusItem == 'aguardando') {
      cardColor = Colors.blueGrey.shade50;
      statusText = 'AGUARDANDO';
    }

    // Para pastéis especiais (não customizados), a lista de ingredientes é apenas o nome do produto
    String ingredientesDisplay = (item.ingredientes.length == 1 && item.ingredientes[0] == item.produtoNome)
        ? item.produtoNome // Exibe só o nome se for Pastel, Pizza ou Misto simples
        : item.ingredientes.join(', '); // Lista de ingredientes para o pastel customizado
    
    // Adiciona o número da posição na fila (apenas para referência visual, não está no modelo)
    final position = index + 1;

    return Card(
      elevation: 6,
      // Cor de fundo dinâmica
      color: cardColor, 
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        // Adiciona uma borda destacada para o primeiro item
        side: index == 0 ? const BorderSide(color: Colors.amber, width: 4) : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Posição na fila, ID do Item e Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Coluna esquerda: Prioridade (Contador Visual sequencial)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PRIORIDADE',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: index == 0 ? Colors.red.shade700 : Colors.blueGrey,
                      ),
                    ),
                    Text(
                      '#$position',
                      style: TextStyle(
                        fontSize: 48, // Tamanho GRANDE para a prioridade
                        fontWeight: FontWeight.w900, 
                        color: index == 0 ? Colors.amber.shade900 : Colors.blueGrey.shade700
                      ),
                    ),
                  ],
                ),
                
                // Coluna direita: Status e ID do Item (DB)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      statusText.toUpperCase(),
                      style: TextStyle(
                        fontSize: 16, 
                        fontWeight: FontWeight.bold,
                        color: index == 0 ? Colors.red.shade700 : Colors.blueGrey,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'ID do Item', // Rastreamento do banco de dados
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    Text(
                      '#${item.id}',
                      style: const TextStyle(
                        fontSize: 16, 
                        fontWeight: FontWeight.w500,
                        color: Colors.black54
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 20),
            
            // Ingredientes / Nome do Produto
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      item.produtoNome,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      ingredientesDisplay,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, height: 1.2),
                    ),
                  ],
                ),
              ),
            ),
            
            // Observações
            if (item.observacoesItem.isNotEmpty) ...[
              const Divider(height: 20),
              Container(
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8)
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('OBS:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.red)),
                    Text(
                      item.observacoesItem,
                      style: const TextStyle(fontSize: 18, fontStyle: FontStyle.italic, color: Colors.red),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}
