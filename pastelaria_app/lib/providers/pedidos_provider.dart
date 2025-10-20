// lib/providers/pedidos_provider.dart
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../models/item_pedido.dart';
import '../services/api_service.dart';

class PedidosProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  late final io.Socket _socket;

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

  PedidosProvider()
      : _socket = io.io('http://localhost:5000', <String, dynamic>{
          'transports': <String>['websocket'],
          'autoConnect': false,
        }) {
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

  void _initWebSocket() {
    _socket.connect();

    _socket.onConnect((_) {
      print('Conectado ao WebSocket!');
    });

    _socket.onDisconnect((_) {
      print('Desconectado do WebSocket!');
    });

    _socket.on('novo_pedido', (data) {
      print('Novo pedido recebido via WebSocket: $data');
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
      _filaEntrega.add(data);
      _listKeyEntrega?.currentState?.insertItem(newIndex, duration: const Duration(milliseconds: 500));

      // A chamada notifyListeners é importante para que o estado seja atualizado.
      notifyListeners();
    });

    _socket.on('status_atualizado', (data) {
      print('Status de item atualizado recebido via WebSocket: $data');
      final int itemId = data['item_id'];
      final String novoStatus = data['novo_status'];
      _updateItemStatusLocal(itemId, novoStatus);
    });

    _socket.on('pedido_atualizado', (data) {
      print('Pedido com status atualizado recebido via WebSocket: $data');
      // Atualiza o pedido na lista de pedidos
      final int pedidoId = data['pedido_id'];
      final String novoStatus = data['novo_status'];
      _updatePedidoStatusLocal(pedidoId, novoStatus);
    });
  }

  // 2. Busca inicial dos itens de pedido
  Future<void> prepareFilaPastel() async {
    try {
      // Busca itens com status 'aguardando' OU 'em_producao'
      _itensPedido =
          await _apiService.getItensPorStatus(['aguardando', 'em_producao']);
      List<ItemPedido> itensPastel = [];
      for (var item in _itensPedido) {
        // Condição atualizada para incluir todos os tipos de pastéis
        if (item.produtoNome == 'Pastel') {
          for (int i = 0; i < item.quantidade; i++) {
            // Cria um novo item para cada unidade, copiando os dados
            itensPastel.add(ItemPedido(
              id: item.id,
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
      print('Erro ao preparar a fila de pastéis: $e');
    }
  }

  Future<void> fetchFilaEntrega() async {
    try {
      // Presumindo que esta chamada API retorna a lista de pedidos a serem despachados
      final List<dynamic> fila = await _apiService.getFilaEntrega();

      // Limpa a lista atual e a preenche com os dados da API
      _filaEntrega = fila;

      // Como é uma carga inicial, não usamos animação.
      // A tela apenas será reconstruída via notifyListeners
      notifyListeners();
    } catch (e) {
      print('Erro ao carregar a fila de entrega: $e');
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
    // Primeiro, atualiza o status no backend
    await _apiService.atualizarStatusItem(itemId, novoStatus);

    // Depois, atualiza a lista local
    for (int i = 0; i < _filaPastel.length; i++) {
      if (_filaPastel[i].id == itemId) {
        final itemAtualizado = ItemPedido(
          id: _filaPastel[i].id,
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
    for (int i = 0; i < _itensPedido.length; i++) {}
    notifyListeners();
  }

  void _updateItemStatusLocal(int itemId, String novoStatus) {
    bool updated = false;
    for (int i = 0; i < _filaPastel.length; i++) {
      if (_filaPastel[i].id == itemId) {
        _filaPastel[i] = ItemPedido(
          id: _filaPastel[i].id,
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
