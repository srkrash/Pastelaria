// lib/models/item_pedido.dart

class ItemPedido {
  final int id;
  final int quantidade;
  final String produtoNome;
  final String statusItem;
  final List<String> ingredientes;
  final String? observacoesItem;

  ItemPedido({
    required this.id,
    required this.quantidade,
    required this.produtoNome,
    required this.statusItem,
    required this.ingredientes,
    this.observacoesItem,
  });

  factory ItemPedido.fromJson(Map<String, dynamic> json) {
    return ItemPedido(
      id: json['item_id'],
      quantidade: json['quantidade'],
      produtoNome: json['produto_nome'],
      statusItem: json['status_item'],
      observacoesItem: json['observacoes_item'],
      ingredientes: List<String>.from(json['ingredientes']),
    );
  }
}