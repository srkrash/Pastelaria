import 'dart:convert';
import 'dart:io';
import 'package:timezone/data/latest.dart' as tz;

import '../pastelaria_app/lib/server/receipt_encoder.dart';
import '../pastelaria_app/lib/server/pix_payment.dart';

/// Uses the app's encoder, without Flutter, production orders or databases.
/// Default is preview only. Run with --packages pointing to the app's package
/// config, then scripts/test_printer.dart HOST [--send].
Future<void> main(List<String> args) async {
  tz.initializeTimeZones();
  if (args.isEmpty) {
    stderr.writeln('Uso: dart scripts/test_printer.dart IP [--send]');
    exitCode = 64;
    return;
  }
  final pixArgument = args
      .where((a) => a.startsWith('--pix-file='))
      .firstOrNull;
  PixConfiguration? pix;
  if (pixArgument != null) {
    final config =
        jsonDecode(await File(pixArgument.substring(11)).readAsString()) as Map;
    pix = PixConfiguration(
      phone: config['phone'] as String,
      name: config['name'] as String,
      city: config['city'] as String,
    );
    pix.validate();
  }
  final bytes = encodeReceipt({
    'id': 0,
    'numero_pedido': 10,
    'data_hora_pedido': DateTime.now().toUtc().toIso8601String(),
    'observacoes':
        'TESTE DE IMPRESSAO\n'
        'NAO PRODUZIR / NAO E PEDIDO REAL\n'
        'CONFERIR OS TRES ITENS E O TOTAL FINAL',
    'total_centavos': pix == null ? 0 : 10,
    'itens': [
      {
        'quantidade': 1,
        'produto_nome': 'TESTE 1 - Pastel de carne',
        'ingredientes': ['Carne', 'Queijo', 'Cebola'],
        'observacoes_item': 'PRIMEIRO ITEM COMPLETO - conferir esta linha',
      },
      {
        'quantidade': 2,
        'produto_nome':
            'TESTE 2 - Pastel com descricao longa para conferir '
            'a quebra de linha automatica sem cortar o restante do cupom',
        'ingredientes': ['Frango', 'Queijo', 'Milho'],
        'observacoes_item': 'SEGUNDO ITEM COMPLETO',
      },
      {
        'quantidade': 1,
        'produto_nome': 'TESTE 3 - Ultimo pastel',
        'ingredientes': ['Chocolate', 'Banana'],
        'observacoes_item': 'FIM DO TESTE - O TOTAL DEVE APARECER ABAIXO',
      },
    ],
  }, pix: pix);
  stdout.writeln(
    'Cupom sintetico: tres itens; total ${pix == null ? "0.00" : "0.10"}; PIX ${pix == null ? "desativado" : "ativado"}.',
  );
  stdout.writeln('${bytes.length} bytes; final: GS V 66 0 (avanco e corte).');
  if (!args.contains('--send')) {
    stdout.writeln('Previa apenas. Acrescente --send para imprimir.');
    return;
  }
  Socket? socket;
  try {
    socket = await Socket.connect(
      args.first,
      9100,
      timeout: const Duration(seconds: 5),
    );
    socket.listen((_) {}, onError: (_) {});
    socket.add(bytes);
    await socket.flush().timeout(const Duration(seconds: 5));
    await socket.close().timeout(const Duration(seconds: 5));
    stdout.writeln(
      'Enviado a ${args.first}:9100. Confira o papel fisicamente.',
    );
  } catch (error) {
    stderr.writeln(
      'Falha ou resultado incerto: $error. Confira antes de repetir.',
    );
    exitCode = 1;
  } finally {
    socket?.destroy();
  }
}
