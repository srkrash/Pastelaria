// lib/models/item_pedido.dart
import 'dart:convert';

class ItemPedido {
  final int id;
  final int pedidoId;
  final int quantidade;
  final String produtoNome;
  final String statusItem;
  final List<String> ingredientes;

  ItemPedido({
    required this.id,
    required this.pedidoId,
    required this.quantidade,
    required this.produtoNome,
    required this.statusItem,
    required this.ingredientes,
  });

  factory ItemPedido.fromJson(Map<String, dynamic> json) {
    return ItemPedido(
      id: json['item_id'],
      pedidoId: json['pedido_id'],
      quantidade: json['quantidade'],
      produtoNome: json['produto_nome'],
      statusItem: json['status_item'],
      ingredientes: List<String>.from(json['ingredientes']),
    );
  }
}