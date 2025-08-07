// lib/providers/pedidos_provider.dart
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../models/item_pedido.dart';
import '../services/api_service.dart';

class PedidosProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  final IO.Socket _socket;

  List<ItemPedido> _itensPedido = [];
  final String _statusFiltroAtual = 'aguardando';

  List<ItemPedido> get itensPedido => _itensPedido;

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

    _socket.on('status_atualizado', (data) {
      print('Status de item atualizado recebido via WebSocket: $data');
      final int itemId = data['item_id'];
      final String novoStatus = data['novo_status'];
      _updateItemStatusLocal(itemId, novoStatus);
    });

    // 1. CORREÇÃO: Ouve o evento 'novo_pedido'
    _socket.on('novo_pedido', (data) {
      print('Novo pedido recebido via WebSocket: $data');

      // 2. Extrai a lista de itens do JSON principal
      final List itensData = data['itens'];
      
      // 3. Itera sobre cada item na lista e o adiciona
      for (var itemJson in itensData) {
        // Usa o ItemPedido.fromJson no JSON de um item individual
        final novoItem = ItemPedido.fromJson(itemJson);

        // Adiciona o item à lista apenas se ele corresponder ao filtro
        if (novoItem.statusItem == _statusFiltroAtual) {
          _itensPedido.add(novoItem);
        }
      }

      notifyListeners(); // Notifica a UI após todos os itens serem adicionados
    });
  }

  // 2. Busca inicial dos itens de pedido
  Future<void> fetchItens() async {
    try {
      _itensPedido = await _apiService.getItensPorStatus(_statusFiltroAtual);
      notifyListeners();
    } catch (e) {
      print('Erro ao buscar itens: $e');
    }
  }

  // 3. Atualiza o status de um item (localmente e na API)
  Future<void> updateStatusItem(int itemId, String novoStatus) async {
    try {
      await _apiService.atualizarStatusItem(itemId, novoStatus);
    } catch (e) {
      print('Erro ao atualizar status na API: $e');
      // Opcional: Reverter o status local se a API falhar
    }
  }

  // Métodos privados para gerenciar o estado local
  void _updateItemStatusLocal(int itemId, String novoStatus) {
    int index = _itensPedido.indexWhere((item) => item.id == itemId);
    if (index != -1) {
      _itensPedido[index] = ItemPedido(
        id: _itensPedido[index].id,
        quantidade: _itensPedido[index].quantidade,
        produtoNome: _itensPedido[index].produtoNome,
        statusItem: novoStatus, // Atualiza o status
        ingredientes: _itensPedido[index].ingredientes,
      );
      notifyListeners();
    }
  }

  void _addNewItemLocal(ItemPedido novoItem) {
    // Adiciona o item apenas se ele corresponder ao filtro atual
    if (novoItem.statusItem == _statusFiltroAtual) {
      _itensPedido.add(novoItem);
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _socket.disconnect();
    super.dispose();
  }
}