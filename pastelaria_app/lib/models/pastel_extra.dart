/// A separately charged filling, quoted per pastel and kept on the sold item.
class PastelExtra {
  final String name;
  final int cents;
  const PastelExtra({required this.name, required this.cents});

  factory PastelExtra.fromJson(Map data) {
    final name = data['nome'];
    final cents = data['preco_centavos'];
    if (name is! String ||
        name.trim().isEmpty ||
        name.trim().length > 80 ||
        RegExp(r'[\x00-\x1f\x7f]').hasMatch(name)) {
      throw const FormatException(
          'Informe o nome do recheio adicional (até 80 caracteres).');
    }
    if (cents is! int || cents < 0 || cents > 999999) {
      throw const FormatException(
          'Valor do adicional inválido: use centavos inteiros de 0 a 999999.');
    }
    return PastelExtra(name: name.trim(), cents: cents);
  }

  Map<String, dynamic> toJson() => {'nome': name, 'preco_centavos': cents};
  String get price =>
      '${cents ~/ 100},${(cents % 100).toString().padLeft(2, '0')}';
  String get description => '$name (+R\$ $price por pastel)';

  static List<PastelExtra> parse(dynamic raw) {
    if (raw == null) return const [];
    if (raw is! List || raw.any((value) => value is! Map)) {
      throw const FormatException('Lista de adicionais inválida.');
    }
    return raw.map((value) => PastelExtra.fromJson(value as Map)).toList();
  }
}

int extraUnitCents(Iterable<PastelExtra> extras) =>
    extras.fold(0, (sum, extra) => sum + extra.cents);
