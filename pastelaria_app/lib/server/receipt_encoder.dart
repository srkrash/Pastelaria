import 'dart:convert';
import 'package:timezone/timezone.dart' as tz;
import 'pix_payment.dart';
import '../models/pastel_extra.dart';

/// Standard-mode ESC/POS receipt. Text never contains printer control commands.
List<int> encodeReceipt(Map<String, dynamic> order,
    {bool secondCopy = false, PixConfiguration? pix}) {
  final lines = <String>[];
  for (final item in order['itens'] as List) {
    lines.add('${item['quantidade']}x ${item['produto_nome']}');
    if ((item['ingredientes'] as List).isNotEmpty) {
      lines.add('  ${(item['ingredientes'] as List).join(', ')}');
    }
    for (final extra in PastelExtra.parse(item['adicionais'])) {
      lines.add('  ADICIONAL: ${extra.description}');
    }
    if (item['observacoes_item'] != '') {
      lines.add('  OBS: ${item['observacoes_item']}');
    }
  }
  final cents = order['total_centavos'] as int;
  lines.add(
      'TOTAL: R\$ ${cents ~/ 100},${(cents % 100).toString().padLeft(2, '0')}');
  final date = tz.TZDateTime.from(
      DateTime.parse(order['data_hora_pedido'] as String),
      tz.getLocation('America/Sao_Paulo'));
  String two(int n) => n.toString().padLeft(2, '0');
  final dateText = '${two(date.day)}/${two(date.month)}/${date.year} '
      '${two(date.hour)}:${two(date.minute)}';
  final ticket = order['numero_pedido'] as int;
  final note = (order['observacoes'] as String? ?? '').trim();
  final divider = '${'-' * 48}\n';
  List<int> text(String value) => ascii.encode(_ascii(value));
  return [
    27, 64, // ESC @: initialize, standard mode and default line spacing.
    27, 97, 1, ...text('PASTELARIA GAUCHA\n'),
    27, 97, 0, ...text(divider),
    if (secondCopy) ...text('*** SEGUNDA VIA ***\n'),
    27, 69, 1, // bold
    29, 33, 17, // double width and height
    ...text(ticket > 0 ? 'PEDIDO: $ticket\n' : 'PEDIDO: BALCAO\n'),
    29, 33, 0, 27, 69, 0, // normal size and weight before date/items
    ...text('Data: $dateText\n$divider'),
    ...text('${lines.join('\n')}\n$divider'),
    if (pix != null && cents > 0) ...[
      27,
      97,
      1,
      ...text('Pagamento com PIX\nChave: ${pix.key.substring(3)}\n'
          'Favorecido: ${pix.name.trim()}\n\n'),
      ...encodePixQr(buildPixPayload(pix, order['total_centavos'] as int,
          txid: 'P${order['id']}')),
    ],
    if (note.isNotEmpty) ...text('OBSERVACAO DO PEDIDO:\n$note\n'),
    27, 97, 1,
    ...text('Obrigado pela compra, volte sempre!\n\n'),
    27, 97, 0,
    // TP-650 command manual, p. 42: GS V 66 n feeds to the cutter and
    // partially cuts. n=0 still feeds to the cutting position. The manual
    // supports m=1/49/66, not the legacy m=0 (full cut).
    29, 86, 66, 0,
  ];
}

String _ascii(String text) {
  const from = 'áàâãäÁÀÂÃÄéèêëÉÈÊËíìîïÍÌÎÏóòôõöÓÒÔÕÖúùûüÚÙÛÜçÇ';
  const to = 'aaaaaAAAAAeeeeEEEEiiiiIIIIoooooOOOOOuuuuUUUUcC';
  return text
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .split('')
      .map((c) {
    final i = from.indexOf(c);
    if (i >= 0) return to[i];
    final code = c.codeUnitAt(0);
    // Keep line breaks, but never pass ESC, GS, NUL or other control bytes
    // from product names, ingredients or observations to the printer.
    return c == '\n' || (code >= 32 && code <= 126) ? c : '?';
  }).join();
}
