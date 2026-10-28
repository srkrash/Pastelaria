import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:pastelaria_app/server/pix_payment.dart';
import 'package:pastelaria_app/server/receipt_encoder.dart';
import 'package:pastelaria_app/services/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;

Map<String, String> fields(String value) {
  final result = <String, String>{};
  var offset = 0;
  while (offset < value.length) {
    final id = value.substring(offset, offset + 2);
    final length = int.parse(value.substring(offset + 2, offset + 4));
    result[id] = value.substring(offset + 4, offset + 4 + length);
    offset += 4 + length;
  }
  return result;
}

const config = PixConfiguration(
    phone: '(11) 99999-0000', name: 'Beneficiário Teste', city: 'São Paulo');

void main() {
  setUpAll(tz.initializeTimeZones);
  test('CRC conhecido e exemplo publicado pelo Banco Central', () {
    expect(pixCrc16('123456789'), '29B1');
    expect(
        pixCrc16(
            '00020126580014br.gov.bcb.pix0136123e4567-e12b-12d1-a456-4266554400005204000053039865802BR5913Fulano de Tal6008BRASILIA62070503***6304'),
        '1D3D');
  });
  test('PIX de dez centavos com telefone E164 e identificador estável', () {
    final payload = buildPixPayload(config, 10, txid: 'P123');
    final data = fields(payload);
    expect(fields(data['26']!)['01'], '+5511999990000');
    expect(fields(data['26']!)['00'], 'br.gov.bcb.pix');
    expect(data['54'], '0.10');
    expect(data['53'], '986');
    expect(data['59'], 'BENEFICIARIO TESTE');
    expect(data['60'], 'SAO PAULO');
    expect(fields(data['62']!)['05'], 'P123');
    expect(data['63'], pixCrc16(payload.substring(0, payload.length - 4)));
    expect(
        config.key,
        const PixConfiguration(
                phone: '+55 (11) 99999-0000', name: 'Teste', city: 'Teste')
            .key);
    expect(fields(buildPixPayload(config, 12345))['54'], '123.45');
    expect(fields(buildPixPayload(config, 1))['54'], '0.01');
  });
  test('rejeita chave, dados e valores inválidos antes do envio', () {
    expect(() => buildPixPayload(config, 0), throwsFormatException);
    expect(() => buildPixPayload(config, -1), throwsFormatException);
    expect(() => buildPixPayload(config, 1000000000000), throwsFormatException);
    expect(
        () => buildPixPayload(config, 10, txid: 'P-1'), throwsFormatException);
    expect(
        () =>
            const PixConfiguration(phone: '11999', name: 'Teste', city: 'Teste')
                .validate(),
        throwsFormatException);
    expect(
        () => const PixConfiguration(
                phone: '11999990000', name: '', city: 'Teste')
            .validate(),
        throwsFormatException);
    expect(
        () => const PixConfiguration(
                phone: '11999990000', name: 'Teste', city: '1234567890123456')
            .validate(),
        throwsFormatException);
  });
  test('QR tem tamanho de armazenamento correto, inclusive acima de 255 bytes',
      () {
    final bytes = encodePixQr(List.filled(300, 'A').join());
    final start = bytes.indexOf(80) - 1; // cn=49, fn=80, m=48
    expect(bytes.sublist(start - 2, start), [47, 1]); // 303 bytes
    expect(bytes.sublist(start, start + 3), [49, 80, 48]);
    expect(bytes.sublist(start + 3, start + 303), List.filled(300, 65));
    expect(bytes.sublist(start + 303, start + 311),
        [29, 40, 107, 3, 0, 49, 81, 48]);
  });
  test('cupom usa total, imprime QR após itens e mantém margem antes do corte',
      () {
    final order = <String, dynamic>{
      'id': 123,
      'numero_pedido': 1,
      'data_hora_pedido': '2026-10-28',
      'observacoes': '',
      'itens': [],
      'total_centavos': 10
    };
    final bytes = encodeReceipt(order, pix: config);
    final payload = ascii.encode(buildPixPayload(config, 10, txid: 'P123'));
    final text = ascii.decode(bytes, allowInvalid: true);
    expect(text.indexOf('Pagamento com PIX'),
        greaterThan(text.indexOf('TOTAL: R\$ 0,10')));
    expect(
        text, contains('Chave: 11999990000\nFavorecido: Beneficiario Teste\n'));
    expect(text, contains(ascii.decode(payload)));
    expect(bytes.sublist(bytes.length - 9), [10, 10, 27, 97, 0, 29, 86, 66, 0]);
    order['total_centavos'] = 0;
    expect(ascii.decode(encodeReceipt(order, pix: config)),
        isNot(contains('Pagamento com PIX')));
  });
  test(
      'configuração PIX sobrevive ao reinício e não muda configurações antigas',
      () async {
    SharedPreferences.setMockInitialValues({});
    expect((await AppSettings.load()).pix, isNull);
    await const AppSettings(
            pixEnabled: true,
            pixPhone: '11999990000',
            pixName: 'Beneficiario Teste',
            pixCity: 'Sao Paulo')
        .save();
    final loaded = await AppSettings.load();
    expect(loaded.pix!.key, config.key);
    expect(loaded.pix!.merchantCity, 'SAO PAULO');
    expect(loaded.printerPort, 9100);
  });
}
