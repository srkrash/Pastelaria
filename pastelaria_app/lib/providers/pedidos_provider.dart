// lib/providers/pedidos_provider.dart
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../models/item_pedido.dart';
import '../services/api_service.dart';

class PedidosProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  final IO.Socket _socket;

  List<ItemPedido> _itensPedido = [];
  List<ItemPedido> _filaPastel = [];

  List<ItemPedido> get itensPedido => _itensPedido;
   List<ItemPedido> get filaPastel => _filaPastel;

  PedidosProvider() : _socket = IO.io('http://localhost:5000', IO.OptionBuilder().setTransports(['websocket']).enableAutoConnect().build()) {
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
        // Verifica se é um pastel e adiciona à fila, destrinchando
        if (itemJson['produto_tipo'] == 'pastel') {
          for (int i = 0; i < itemJson['quantidade']; i++) {
            _filaPastel.add(ItemPedido.fromJson(itemJson));
          }
        }
      }
      notifyListeners();
    });

    // Lógica para atualizar o status em tempo real
    _socket.on('status_atualizado', (data) {
      print('Status de item atualizado recebido via WebSocket: $data');
      final int itemId = data['item_id'];
      final String novoStatus = data['novo_status'];
      _updateItemStatusLocal(itemId, novoStatus);
    });
  }

  void _updateItemStatusLocal(int itemId, String novoStatus) {
  // Encontra o índice do item na lista 'itensPedido'
  final itemIndex = _itensPedido.indexWhere((item) => item.id == itemId);
  
  if (itemIndex != -1) { // Verifica se o item foi encontrado
    // Pega o item atual
    final itemAtual = _itensPedido[itemIndex];
    
    // Cria uma nova instância do item com o status atualizado
    final itemAtualizado = ItemPedido(
      id: itemAtual.id,
      quantidade: itemAtual.quantidade,
      produtoNome: itemAtual.produtoNome,
      statusItem: novoStatus, // Atualiza o status
      ingredientes: itemAtual.ingredientes,
      observacoesItem: itemAtual.observacoesItem,
    );
    
    // Substitui o item antigo pelo novo na lista
    _itensPedido[itemIndex] = itemAtualizado;

    // Notifica os widgets que a lista mudou
    notifyListeners();
  }
}

  // 2. Busca inicial dos itens de pedido
   Future<void> prepareFilaPastel() async {
    try {
      // Busca itens com status 'aguardando' OU 'em_producao'
      _itensPedido = await _apiService.getItensPorStatus(['aguardando', 'em_producao']);
      
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

  Future<void> _atualizarStatusDeTodosItens(int itemId, String novoStatus) async {
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

  // Novo método para avançar a fila e atualizar o status
  Future<void> avancarFila(GlobalKey<AnimatedListState> listKey) async {
    if (_filaPastel.isNotEmpty) {
      final itemPronto = _filaPastel.removeAt(0);

      // Remove o item da lista com uma animação
      listKey.currentState?.removeItem(
        0, // Índice do item a ser removido
        (context, animation) => _buildRemovedItem(itemPronto, animation),
        duration: const Duration(milliseconds: 500),
      );

      // Atualiza o status do item removido para 'pronto'
      await _atualizarStatusDeTodosItens(itemPronto.id, 'pronto');

      // Adiciona um novo item na fila (se houver) de forma animada
      // A lógica para adicionar um novo item pode ser mais complexa
      // e depende de como novos itens chegam. Por enquanto, a fila
      // apenas se move, e o espaço é preenchido com o próximo item.
      
      // Atualiza o status do primeiro item visível para 'em_preparacao'
      if (_filaPastel.isNotEmpty) {
        final primeiroItem = _filaPastel.first;
        if (primeiroItem.statusItem == 'aguardando') {
          await _atualizarStatusDeTodosItens(primeiroItem.id, 'em_preparacao');
        }
      }
      notifyListeners();
    }
  }
  Widget _buildRemovedItem(ItemPedido item, Animation<double> animation) {
    return SizeTransition(
      sizeFactor: animation,
      axis: Axis.horizontal,
      child: Card(
        // ... (código do card, pode ser extraído para um método) ...
        child: Text('Removendo: ${item.produtoNome}'),
      ),
    );
  }
}