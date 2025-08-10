// lib/providers/pedidos_provider.dart
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../models/item_pedido.dart';
import '../services/api_service.dart';

class PedidosProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  late final IO.Socket _socket;

  List<ItemPedido> _itensPedido = [];
  List<ItemPedido> _filaPastel = [];

  List<ItemPedido> get filaPastel => _filaPastel;

  // A CHAVE GLOBAL AGORA ESTÁ NO PROVEDOR
  GlobalKey<AnimatedListState>? _listKey;

  void setListKey(GlobalKey<AnimatedListState> key) {
    _listKey = key;
  }

  PedidosProvider()
      : _socket = IO.io('http://localhost:5000', <String, dynamic>{
          'transports': <String>['websocket'],
          'autoConnect': false,
        }) {
    _initWebSocket();
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
          _listKey?.currentState?.insertItem(newIndex, duration: const Duration(milliseconds: 500));
        }
      }
    }
    // A chamada notifyListeners é importante para que o estado seja atualizado.
    notifyListeners();
  });

  _socket.on('status_atualizado', (data) {
    print('Status de item atualizado recebido via WebSocket: $data');
    final int itemId = data['item_id'];
    final String novoStatus = data['novo_status'];
    _updateItemStatusLocal(itemId, novoStatus);
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
        if (item.produtoNome == 'Pastel') {
          for (int i = 0; i < item.quantidade; i++) {
            // Cria um novo item para cada unidade, copiando os dados
            itensPastel.add(ItemPedido(
              id: item.id,
              quantidade: 1, // Fixa a quantidade em 1
              produtoNome: item.produtoNome,
              statusItem: item.statusItem,
              ingredientes: item.ingredientes,
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

  Future<void> avancarFila() async {
    if (_filaPastel.isNotEmpty) {
      final itemPronto = _filaPastel.removeAt(0);

      _listKey?.currentState?.removeItem(
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
          ingredientes: _filaPastel[i].ingredientes,
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

  void _updateItemStatusLocal(int itemId, String novoStatus) {
    bool updated = false;
    for (int i = 0; i < _filaPastel.length; i++) {
      if (_filaPastel[i].id == itemId) {
        _filaPastel[i] = ItemPedido(
          id: _filaPastel[i].id,
          quantidade: _filaPastel[i].quantidade,
          produtoNome: _filaPastel[i].produtoNome,
          statusItem: novoStatus,
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
