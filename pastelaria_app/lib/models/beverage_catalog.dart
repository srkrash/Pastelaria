enum BeverageCategory {
  cans('Refrigerantes em lata'),
  beer('Cervejas'),
  soda600('Refrigerantes 600 ml'),
  soda1l('Refrigerantes 1 litro'),
  soda2l('Refrigerantes 2 litros'),
  small('Refrigerantes pequenos'),
  water('Águas'),
  juice('Sucos'),
  energy('Energéticos'),
  other('Outras bebidas');

  final String label;
  const BeverageCategory(this.label);
}

/// Presentation only: stable product IDs, names and prices remain on the server.
class BeverageCatalog {
  static String normalize(String value) {
    const from = 'áàâãäéèêëíìîïóòôõöúùûüç';
    const to = 'aaaaaeeeeiiiiooooouuuuc';
    return value
        .toLowerCase()
        .split('')
        .map((c) {
          final index = from.indexOf(c);
          return index < 0 ? c : to[index];
        })
        .join()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  static bool _volume(String name, int ml) {
    if (RegExp('(?:^| )$ml\\s*ml(?: |\$)').hasMatch(name)) return true;
    return ml % 1000 == 0 &&
        RegExp('(?:^| )${ml ~/ 1000}\\s*(?:l|litros?)(?: |\$)').hasMatch(name);
  }

  static BeverageCategory category(String value) {
    final name = normalize(value);
    if (name.contains('agua')) return BeverageCategory.water;
    if (name.contains('suco')) return BeverageCategory.juice;
    if (name.contains('energetico') ||
        name.contains('extra power') ||
        name.contains('red bull') ||
        name.contains('monster')) {
      return BeverageCategory.energy;
    }
    if (name.contains('cerveja') ||
        ['amstel', 'skol', 'brahma', 'heineken'].any(name.contains) ||
        name.contains('antarctica') &&
            !name.contains('guarana') &&
            !name.contains('tonica')) {
      return BeverageCategory.beer;
    }
    if (_volume(name, 200) || _volume(name, 250)) return BeverageCategory.small;
    if (name.contains('lata') || _volume(name, 350) || _volume(name, 310)) {
      return BeverageCategory.cans;
    }
    if (_volume(name, 600)) return BeverageCategory.soda600;
    if (_volume(name, 1000)) return BeverageCategory.soda1l;
    if (_volume(name, 2000)) return BeverageCategory.soda2l;
    return BeverageCategory.other;
  }

  static String? image(String value) {
    final name = normalize(value);
    if ([BeverageCategory.water, BeverageCategory.juice]
        .contains(category(value))) {
      return null;
    }
    String? key;
    if (name.contains('coca')) {
      final zero = name.contains('zero') || name.contains('sem acucar');
      if (name.contains('lata') || _volume(name, 350)) {
        key = zero ? 'coca_zero_lata' : 'coca_lata';
      } else if (_volume(name, 600) && !zero) {
        key = 'coca_600';
      } else if (_volume(name, 1000)) {
        key = zero ? 'coca_zero_1l' : 'coca_1l';
      } else if (_volume(name, 2000) && !zero) {
        key = 'coca_2l';
      }
    } else if (name.contains('fanta') &&
        !name.contains('uva') &&
        !name.contains('zero')) {
      if (name.contains('lata')) {
        key = 'fanta_lata';
      } else if (_volume(name, 1000)) {
        key = 'fanta_1l';
      } else if (_volume(name, 2000)) {
        key = 'fanta_2l';
      }
    } else if (name.contains('sprite') && name.contains('lata')) {
      key = 'sprite_lata';
    } else if (name.contains('mineiro') || name.contains('mineirinho')) {
      if (_volume(name, 200)) return 'assets/bebidas/mineiro_200.png';
      if (_volume(name, 250)) {
        key = 'mineiro_250';
      } else if (name.contains('lata')) {
        key = 'mineiro_lata';
      } else if (_volume(name, 600)) {
        key = 'mineiro_600';
      } else if (_volume(name, 2000)) {
        key = 'mineiro_2l';
      }
    } else if (category(value) == BeverageCategory.beer) {
      for (final brand in [
        'amstel',
        'skol',
        'brahma',
        'antarctica',
        'heineken'
      ]) {
        if (name.contains(brand)) {
          key = '${brand}_lata';
          break;
        }
      }
    } else if (name.contains('extra power')) {
      key = 'extra_power';
    }
    return key == null ? null : 'assets/bebidas/$key.jpg';
  }
}
