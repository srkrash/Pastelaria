// lib/models/produto.dart
class Produto {
  final String nome;
  final String tipo; // Ex: 'pastel', 'bebida', 'salgado'
  final double preco;

  const Produto({
    required this.nome,
    required this.tipo,
    required this.preco,
  });
}