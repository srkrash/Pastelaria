// lib/models/pedido.dart
import 'item_pedido.dart';

class Pedido {
  final int pedidoId;
  final int numeroPedido;
  final String? observacoes; // Pode ser nulo
  final List<ItemPedido> itens;

  Pedido({
    required this.pedidoId,
    required this.numeroPedido,
    this.observacoes,
    required this.itens,
  });

  factory Pedido.fromJson(Map<String, dynamic> json) {
    var itensList = json['itens'] as List;
    List<ItemPedido> itens = itensList.map((itemJson) => ItemPedido.fromJson(itemJson)).toList();

    return Pedido(
      pedidoId: json['pedido_id'],
      numeroPedido: json['numero_pedido'],
      observacoes: json['observacoes'],
      itens: itens,
    );
  }
}