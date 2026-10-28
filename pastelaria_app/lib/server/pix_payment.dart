import 'dart:convert';

/// Static BR Code, generated locally; never confirms receipt of payment.
class PixConfiguration {
  final String phone;
  final String name;
  final String city;
  const PixConfiguration(
      {required this.phone, required this.name, required this.city});

  String get key {
    final digits = phone.replaceAll(RegExp(r'[ ()+\-]'), '');
    final value = digits.length == 11 ? '+55$digits' : '+$digits';
    if (!RegExp(r'^\+55[1-9][0-9]9[0-9]{8}$').hasMatch(value)) {
      throw const FormatException(
          'Informe um celular brasileiro com DDD para o PIX.');
    }
    return value;
  }

  String get merchantName => _name(name, 25, 'Nome');
  String get merchantCity => _name(city, 15, 'Cidade');
  void validate() {
    key;
    merchantName;
    merchantCity;
  }
}

String _name(String value, int limit, String label) {
  const from = 'ÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ';
  const to = 'AAAAAEEEEIIIIOOOOOUUUUC';
  final result = value
      .trim()
      .toUpperCase()
      .split('')
      .map((c) {
        final index = from.indexOf(c);
        return index < 0 ? c : to[index];
      })
      .join()
      .replaceAll(RegExp(r'\s+'), ' ');
  if (result.isEmpty ||
      result.length > limit ||
      !RegExp(r'^[A-Z0-9 .\-]+$').hasMatch(result)) {
    throw FormatException(
        '$label do PIX deve ter de 1 a $limit caracteres, sem símbolos especiais.');
  }
  return result;
}

String _field(String id, String value) {
  final length = utf8.encode(value).length;
  if (length > 99) throw const FormatException('Campo PIX excede 99 bytes.');
  return '$id${length.toString().padLeft(2, '0')}$value';
}

String buildPixPayload(PixConfiguration config, int cents,
    {String txid = '***'}) {
  if (cents <= 0 || cents > 999999999999) {
    throw const FormatException('Valor do PIX fora do intervalo permitido.');
  }
  if (txid != '***' && !RegExp(r'^[A-Za-z0-9]{1,25}$').hasMatch(txid)) {
    throw const FormatException('Identificador PIX inválido.');
  }
  final amount = '${cents ~/ 100}.${(cents % 100).toString().padLeft(2, '0')}';
  final body = [
    _field('00', '01'),
    _field('26', _field('00', 'br.gov.bcb.pix') + _field('01', config.key)),
    _field('52', '0000'),
    _field('53', '986'),
    _field('54', amount),
    _field('58', 'BR'),
    _field('59', config.merchantName),
    _field('60', config.merchantCity),
    _field('62', _field('05', txid)),
    '6304',
  ].join();
  return '$body${pixCrc16(body)}';
}

/// CRC-16/CCITT-FALSE: polynomial 0x1021, initial value 0xFFFF.
String pixCrc16(String data) {
  var crc = 0xffff;
  for (final byte in utf8.encode(data)) {
    crc ^= byte << 8;
    for (var bit = 0; bit < 8; bit++) {
      crc = ((crc & 0x8000) != 0 ? (crc << 1) ^ 0x1021 : crc << 1) & 0xffff;
    }
  }
  return crc.toRadixString(16).toUpperCase().padLeft(4, '0');
}

/// TP-650 manual pp. 76–78: model 2, 6-dot modules, correction M, store/print.
List<int> encodePixQr(String payload) {
  final data = ascii.encode(payload);
  final length = data.length + 3;
  return [
    27, 97, 1, // center, preserve quiet zone horizontally
    29, 40, 107, 4, 0, 49, 65, 50, 0,
    29, 40, 107, 3, 0, 49, 67, 6,
    29, 40, 107, 3, 0, 49, 69, 49,
    29, 40, 107, length & 255, length >> 8, 49, 80, 48, ...data,
    29, 40, 107, 3, 0, 49, 81, 48,
    10, 10, // quiet zone below QR
    27, 97, 0,
  ];
}
