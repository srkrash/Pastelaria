// lib/providers/pedidos_provider.dart
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../models/item_pedido.dart';
import '../services/api_service.dart';
import '../services/ip_storage.dart';

class PedidosProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  late io.Socket _socket;

  List<ItemPedido> _itensPedido = [];
  List<ItemPedido> _filaPastel = [];
  List<ItemPedido> get filaPastel => _filaPastel;
  GlobalKey<AnimatedListState>? _listKeyPastel;

  List<dynamic> _filaEntrega = [];
  List<dynamic> get filaEntrega => _filaEntrega;
  GlobalKey<AnimatedListState>? _listKeyEntrega;

  void setListKey(GlobalKey<AnimatedListState> key) {
    _listKeyPastel = key;
  }

  void setListKeyEntrega(GlobalKey<AnimatedListState> key) {
    _listKeyEntrega = key;
  }

  PedidosProvider._internal();

  static Future<PedidosProvider> create() async {
    final provider = PedidosProvider._internal();
    
    // 3. Obtém o IP salvo (ou usa um fallback)
    final serverIp = await IpStorage.getIp() ?? 'localhost'; 
    final socketUrl = 'http://$serverIp:5000';
    
    // 4. Inicializa o socket com o IP correto
    debugPrint('PedidosProvider: Inicializando socket em $socketUrl');
    provider._socket = io.io(socketUrl, <String, dynamic>{
      'transports': <String>['websocket'],
      'autoConnect': true,
    });
    
    // 5. Inicializa os ouvintes do WebSocket
    provider._initWebSocket(); 
    
    return provider;
  }

  Future<void> updateConnection() async {
    // Desconecta o socket atual se estiver conectado
    if (_socket.connected) {
      _socket.disconnect();
    }
    
    // Obtém o novo IP
    final serverIp = await IpStorage.getIp() ?? 'localhost';
    final socketUrl = 'http://$serverIp:5000';
    
    // Reinicializa o socket com o novo URL
    debugPrint('PedidosProvider: Reconectando socket em $socketUrl');
    _socket = io.io(socketUrl, <String, dynamic>{
      'transports': <String>['websocket'],
      'autoConnect': true,
    });
    
    // Reconfigura os ouvintes
    _initWebSocket();
  }

  // Lista de itens do pedido atual
  final List<ItemPedido> _itensPedidoAtual = [];

  List<ItemPedido> get itensPedidoAtual => _itensPedidoAtual;

  void adicionarItem(ItemPedido item) {
    _itensPedidoAtual.add(item);
    notifyListeners();
  }

  void removerItem(ItemPedido item) {
    _itensPedidoAtual.remove(item);
    notifyListeners();
  }

  void limparPedido() {
    _itensPedidoAtual.clear();
    notifyListeners();
  }

  // Estado para armazenar o último pedido confirmado
  Map<String, dynamic>? _ultimoPedidoConfirmado;
  Map<String, dynamic>? get ultimoPedidoConfirmado => _ultimoPedidoConfirmado;

  void setUltimoPedido(int numero, double total) {
    _ultimoPedidoConfirmado = {
      'numero': numero,
      'total': total,
    };
    notifyListeners();
  }

  void _initWebSocket() {
    _socket.connect();

    _socket.onConnect((_) {
      debugPrint('PedidosProvider: Conectado ao WebSocket!');
    });

    _socket.onDisconnect((_) {
      debugPrint('PedidosProvider: Desconectado do WebSocket!');
    });

    _socket.on('novo_pedido', (data) {
      debugPrint('PedidosProvider: Novo pedido recebido via WebSocket: $data');
      final List<dynamic> itensJson = data['itens'];
      for (var itemJson in itensJson) {
        if (itemJson['produto_tipo'] == 'pastel') {
          for (int i = 0; i < itemJson['quantidade']; i++) {
            // 1. OBTÉM O ÍNDICE CORRETO ANTES DE ADICIONAR O ITEM
            final int newIndex = _filaPastel.length;

            // 2. ADICIONA O ITEM NA LISTA
            final novoItem = ItemPedido.fromJson(itemJson);
            _filaPastel.add(novoItem);

            // 3. ANIMA A ADIÇÃO USANDO O ÍNDICE CORRETO
            _listKeyPastel?.currentState?.insertItem(newIndex,
                duration: const Duration(milliseconds: 500));
          }
        }
      }
      final int newIndex = _filaEntrega.length;
      
      // Verifica se o pedido tem número positivo (tem pastel).
      // Se for negativo, não adiciona na fila de entrega.
      final int numeroPedido = data['numero_pedido'] ?? 0;
      
      if (numeroPedido > 0) {
        _filaEntrega.add(data);
        _listKeyEntrega?.currentState?.insertItem(newIndex, duration: const Duration(milliseconds: 500));
      } else {
        debugPrint('PedidosProvider: Pedido #$numeroPedido ignorado na fila de entrega (Sem Pastel).');
      }

      // A chamada notifyListeners é importante para que o estado seja atualizado.
      notifyListeners();
    });

    _socket.on('status_atualizado', (data) {
      debugPrint('PedidosProvider: Status de item atualizado recebido via WebSocket: $data');
      final int itemId = data['item_id'];
      final String novoStatus = data['novo_status'];
      _updateItemStatusLocal(itemId, novoStatus);
    });

    _socket.on('pedido_atualizado', (data) {
      debugPrint('PedidosProvider: Pedido com status atualizado recebido via WebSocket: $data');
      // Atualiza o pedido na lista de pedidos
      final int pedidoId = data['pedido_id'];
      final String novoStatus = data['novo_status'];
      _updatePedidoStatusLocal(pedidoId, novoStatus);
    });
  }

  // 2. Busca inicial dos itens de pedido
  Future<void> prepareFilaPastel() async {
    try {
      debugPrint('PedidosProvider: Buscando itens para fila de pastel...');
      // Busca itens com status 'aguardando' OU 'em_producao'
      _itensPedido =
          await _apiService.getItensPorStatus(['aguardando', 'em_producao']);
      debugPrint('PedidosProvider: ${_itensPedido.length} itens encontrados.');
      List<ItemPedido> itensPastel = [];
      for (var item in _itensPedido) {
        // Condição atualizada para incluir todos os tipos de pastéis
        if (item.produtoNome == 'Pastel') {
          for (int i = 0; i < item.quantidade; i++) {
            // Cria um novo item para cada unidade, copiando os dados
            itensPastel.add(ItemPedido(
              id: item.id,
              pedidoId: item.pedidoId, // Copia o pedidoId
              numeroPedido: item.numeroPedido,
              quantidade: 1, // Fixa a quantidade em 1
              produtoNome: item.produtoNome,
              statusItem: item.statusItem,
              preco: item.preco,
              ingredientes: item.ingredientes,
              observacoesItem: item
                  .observacoesItem, // Adicione este campo para que a observação também seja copiada
            ));
          }
        } else if (item.produtoNome == 'Pizza' || item.produtoNome == 'Misto') {
          for (int i = 0; i < item.quantidade; i++) {
            // Cria um novo item para cada unidade, copiando os dados
            itensPastel.add(ItemPedido(
              id: item.id,
              pedidoId: item.pedidoId, // Copia o pedidoId
              numeroPedido: item.numeroPedido,
              quantidade: 1, // Fixa a quantidade em 1
              produtoNome: item.produtoNome,
              statusItem: item.statusItem,
              preco: item.preco,
              ingredientes: [item.produtoNome],
              observacoesItem: item
                  .observacoesItem, // Adicione este campo para que a observação também seja copiada
            ));
          }
        }
      }
      _filaPastel = itensPastel;
      notifyListeners();
    } catch (e) {
      debugPrint('PedidosProvider: Erro ao preparar a fila de pastéis: $e');
    }
  }

  Future<void> fetchFilaEntrega() async {
    try {
      debugPrint('PedidosProvider: Buscando fila de entrega...');
      // Presumindo que esta chamada API retorna a lista de pedidos a serem despachados
      final List<dynamic> fila = await _apiService.getFilaEntrega();
      debugPrint('PedidosProvider: Fila de entrega carregada com ${fila.length} itens.');

      // Limpa a lista atual e a preenche com os dados da API
      _filaEntrega = fila;

      // Como é uma carga inicial, não usamos animação.
      // A tela apenas será reconstruída via notifyListeners
      notifyListeners();
    } catch (e) {
      debugPrint('PedidosProvider: Erro ao carregar a fila de entrega: $e');
      // Trate o erro
    }
  }

  void removerPedidoEntrega(int index) {
    _filaEntrega.removeAt(index);
    notifyListeners();
  }

  Future<void> avancarFila() async {
    if (_filaPastel.isNotEmpty) {
      final itemPronto = _filaPastel.removeAt(0);
      debugPrint('PedidosProvider: Avançando fila. Item concluído: ${itemPronto.id}');

      _listKeyPastel?.currentState?.removeItem(
        0,
        (context, animation) => _buildRemovedItem(itemPronto, animation),
        duration: const Duration(milliseconds: 500),
      );

      await _atualizarStatusDeTodosItens(itemPronto.id, 'pronto');

      if (_filaPastel.isNotEmpty) {
        final primeiroItem = _filaPastel.first;
        if (primeiroItem.statusItem == 'aguardando') {
          await _atualizarStatusDeTodosItens(primeiroItem.id, 'em_preparacao');
        }
      }
      // A chamada notifyListeners aqui é fundamental para que o estado do item seja atualizado
      notifyListeners();
    }
  }

  Future<void> _atualizarStatusDeTodosItens(
      int itemId, String novoStatus) async {
    debugPrint('PedidosProvider: Atualizando status do item $itemId para $novoStatus');
    // Primeiro, atualiza o status no backend
    await _apiService.atualizarStatusItem(itemId, novoStatus);

    // Depois, atualiza a lista local
    for (int i = 0; i < _filaPastel.length; i++) {
      if (_filaPastel[i].id == itemId) {
        final itemAtualizado = ItemPedido(
          id: _filaPastel[i].id,
          pedidoId: _filaPastel[i].pedidoId,
          numeroPedido: _filaPastel[i].numeroPedido,
          quantidade: _filaPastel[i].quantidade,
          produtoNome: _filaPastel[i].produtoNome,
          statusItem: novoStatus, // Atualiza o status
          preco: _filaPastel[i].preco,
          ingredientes: _filaPastel[i].ingredientes,
          observacoesItem: _filaPastel[i].observacoesItem,
        );
        _filaPastel[i] = itemAtualizado;
      }
    }
    notifyListeners();
  }

  Widget _buildRemovedItem(ItemPedido item, Animation<double> animation) {
    return SizeTransition(
      sizeFactor: animation,
      axis: Axis.horizontal,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text('Removendo: Item #${item.id}',
              style: const TextStyle(fontSize: 16, color: Colors.red)),
        ),
      ),
    );
  }

  void _updatePedidoStatusLocal(int pedidoId, String novoStatus) {
    debugPrint('PedidosProvider: Atualizando status local do pedido $pedidoId para $novoStatus');
    
    // Se o pedido foi cancelado ou fechado, removemos todos os itens desse pedido da fila de pastéis
    if (novoStatus == 'cancelado' || novoStatus == 'fechado') {
      debugPrint('PedidosProvider: Iniciando remoção de itens do pedido $pedidoId (Status: $novoStatus)');
      // Itera de trás para frente para remover itens com segurança
      for (int i = _filaPastel.length - 1; i >= 0; i--) {
        debugPrint('PedidosProvider: Verificando item ${_filaPastel[i].id} com pedidoId ${_filaPastel[i].pedidoId}');
        if (_filaPastel[i].pedidoId == pedidoId) {
          final itemRemovido = _filaPastel[i];
          _filaPastel.removeAt(i);
          
          // Anima a remoção visualmente
          _listKeyPastel?.currentState?.removeItem(
            i,
            (context, animation) => _buildRemovedItem(itemRemovido, animation),
            duration: const Duration(milliseconds: 500),
          );
          debugPrint('PedidosProvider: Item ${itemRemovido.id} removido da fila (Pedido $novoStatus)');
        }
      }

      // REMOÇÃO DA FILA DE ENTREGA
      for (int i = _filaEntrega.length - 1; i >= 0; i--) {
        final pId = int.tryParse(_filaEntrega[i]['pedido_id']?.toString() ?? '0') ?? 0;
         if (pId == pedidoId) {
            final pedidoRemovido = _filaEntrega[i];
            _filaEntrega.removeAt(i);
             _listKeyEntrega?.currentState?.removeItem(
                i,
            (context, animation) => _buildRemovedPedidoEntrega(pedidoRemovido, animation),
            duration: const Duration(milliseconds: 500),
          );
          debugPrint('PedidosProvider: Pedido $pedidoId removido da fila de entrega (Status: $novoStatus)');
         }
      }
    }
    
    notifyListeners();
  }

  Widget _buildRemovedPedidoEntrega(dynamic pedido, Animation<double> animation) {
     return SizeTransition(
      sizeFactor: animation,
      axis: Axis.vertical, 
      child: Card(
        color: Colors.red.shade50,
        child: ListTile(
          title: Text('Removendo Pedido #${pedido['numero_pedido']}', style: const TextStyle(color: Colors.red)),
        ),
      ),
    );
  }

  void _updateItemStatusLocal(int itemId, String novoStatus) {
    bool updated = false;
    for (int i = 0; i < _filaPastel.length; i++) {
      if (_filaPastel[i].id == itemId) {
        _filaPastel[i] = ItemPedido(
          id: _filaPastel[i].id,
          pedidoId: _filaPastel[i].pedidoId,
          numeroPedido: _filaPastel[i].numeroPedido,
          quantidade: _filaPastel[i].quantidade,
          produtoNome: _filaPastel[i].produtoNome,
          statusItem: novoStatus,
          preco: _filaPastel[i].preco,
          ingredientes: _filaPastel[i].ingredientes,
          observacoesItem: _filaPastel[i].observacoesItem,
        );
        updated = true;
      }
    }
    if (updated) {
      notifyListeners();
    }
  }
}
