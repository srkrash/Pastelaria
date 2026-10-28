class PricingRules {
  static int? parsePrice(String text) {
    final value = text.trim().replaceAll('.', ',');
    if (!RegExp(r'^\d{1,4}(,\d{1,2})?$').hasMatch(value)) return null;
    final parts = value.split(',');
    return int.parse(parts[0]) * 100 +
        (parts.length == 1 ? 0 : int.parse(parts[1].padRight(2, '0')));
  }

  final int base, extra, pizza, misto;
  const PricingRules(
      {this.base = 1200,
      this.extra = 300,
      this.pizza = 1500,
      this.misto = 2500});
  factory PricingRules.fromJson(Map data) => PricingRules(
      base: data['base_centavos'] as int,
      extra: data['adicional_centavos'] as int,
      pizza: data['pizza_centavos'] as int,
      misto: data['misto_centavos'] as int);
  Map<String, int> toJson() => {
        'base_centavos': base,
        'adicional_centavos': extra,
        'pizza_centavos': pizza,
        'misto_centavos': misto
      };
  int pastel(List<String> ingredients) {
    if (ingredients.length == 1 && ingredients.single == 'Pizza') return pizza;
    if (ingredients.length == 1 && ingredients.single == 'Misto') return misto;
    final paid = ingredients
        .where((v) => !['Cebola', 'Cebolinha', 'Orégano'].contains(v))
        .length;
    return base + (paid > 2 ? (paid - 2) * extra : 0);
  }
}
