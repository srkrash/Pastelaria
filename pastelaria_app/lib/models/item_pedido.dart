import 'pastel_extra.dart';

class ItemPedido {
  int id;
  int pedidoId;
  int numeroPedido; // Novo campo para o número do pedido
  int quantidade;
  String produtoNome;
  String statusItem;
  double preco;
  List<String> ingredientes;
  String observacoesItem;
  final List<PastelExtra> adicionais;

  ItemPedido({
    required this.id,
    required this.pedidoId,
    required this.numeroPedido,
    required this.quantidade,
    required this.produtoNome,
    required this.statusItem,
    required this.preco,
    required this.ingredientes,
    required this.observacoesItem,
    List<PastelExtra> adicionais = const [],
  }) : adicionais = List.unmodifiable(adicionais);

  factory ItemPedido.fromJson(Map<String, dynamic> json) {
    // CORREÇÃO: Trata o 'preco' de forma segura
    final dynamic precoRaw = json['preco'];
    double parsedPreco;
    if (precoRaw is num) {
      parsedPreco = precoRaw.toDouble();
    } else if (precoRaw is String) {
      // Tenta fazer o parse para double. Se falhar, usa 0.0.
      parsedPreco = double.tryParse(precoRaw) ?? 0.0;
    } else {
      parsedPreco = 0.0; // Caso seja null ou outro tipo
    }

    // CORREÇÃO: Lida com a possibilidade de 'id' e 'quantidade' serem nulos ou outros tipos.
    final int id = (json['item_id'] as num? ?? 0).toInt();
    final int pedidoId =
        (json['pedido_id'] as num? ?? 0).toInt(); // Lê o pedido_id
    final int numeroPedido =
        (json['numero_pedido'] as num? ?? 0).toInt(); // Lê o numero_pedido
    final int quantidade = (json['quantidade'] as num? ?? 0).toInt();

    // Converte a lista de ingredientes, se existir
    List<String> ingredientesList;
    if (json['ingredientes'] != null && json['ingredientes'] is List) {
      ingredientesList = List<String>.from(json['ingredientes']);
    } else {
      ingredientesList = [];
    }

    return ItemPedido(
      id: id,
      pedidoId: pedidoId,
      numeroPedido: numeroPedido,
      quantidade: quantidade,
      produtoNome: json['produto_nome'] ?? '',
      statusItem: json['status_item'] ?? '',
      preco: parsedPreco,
      ingredientes: ingredientesList,
      observacoesItem: json['observacoes_item'] ?? '',
      adicionais: PastelExtra.parse(json['adicionais']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'pedidoId': pedidoId,
      'quantidade': quantidade,
      'produtoNome': produtoNome,
      'statusItem': statusItem,
      'preco': preco,
      'ingredientes': ingredientes,
      'observacoesItem': observacoesItem,
      'adicionais': adicionais.map((extra) => extra.toJson()).toList(),
    };
  }
}
