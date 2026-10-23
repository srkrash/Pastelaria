import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'order_store.dart';

/// Failed/ambiguous jobs require operator review, never an automatic resend.
class PrinterWorker {
  final OrderStore store;
  final String host;
  final int port;
  Timer? _timer;
  bool _busy = false;
  Future<void>? _active;
  PrinterWorker(this.store, this.host, this.port);
  Future<void> start() async {
    await store.db.update(
        'print_jobs',
        {
          'status': 'incerto',
          'error':
              'Servidor reiniciado durante envio. Confira o papel antes de reimprimir.'
        },
        where: 'status = ?',
        whereArgs: ['enviando']);
    _timer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!_busy) _active = _tick();
    });
  }

  Future<void> stop() async {
    _timer?.cancel();
    await _active;
  }

  Future<void> _tick() async {
    if (_busy || host.isEmpty) return;
    _busy = true;
    Socket? socket;
    int? jobId;
    var sending = false;
    try {
      final jobs = await store.db.query('print_jobs',
          where: 'status = ?',
          whereArgs: ['pendente'],
          orderBy: 'id',
          limit: 1);
      if (jobs.isEmpty) return;
      final job = jobs.single;
      jobId = job['id'] as int;
      final order = await store.order(job['order_id'] as int);
      await store.db.update('print_jobs', {'status': 'enviando'},
          where: 'id = ?', whereArgs: [jobId]);
      socket =
          await Socket.connect(host, port, timeout: const Duration(seconds: 5));
      socket.listen((_) {}, onError: (_) {});
      final lines = <String>[
        'PASTELARIA GAUCHA',
        if (job['second_copy'] == 1) '*** SEGUNDA VIA ***',
        order['numero_pedido'] > 0
            ? 'SENHA: ${order['numero_pedido']}'
            : 'BALCAO / SEM PASTEL',
        'PEDIDO INTERNO: ${order['id']}',
        order['data_hora_pedido'] as String,
        '${order['observacoes']}',
        '------------------------------------------',
      ];
      for (final item in order['itens'] as List) {
        lines.add('${item['quantidade']}x ${item['produto_nome']}');
        if ((item['ingredientes'] as List).isNotEmpty) {
          lines.add('  ${(item['ingredientes'] as List).join(', ')}');
        }
        if (item['observacoes_item'] != '') {
          lines.add('  OBS: ${item['observacoes_item']}');
        }
      }
      lines.add(
          'TOTAL: R\$ ${(order['total_centavos'] / 100).toStringAsFixed(2)}');
      // Conservative ASCII until the printer code page is physically validated.
      final text = _ascii('${lines.join('\n')}\n\n\n');
      sending = true;
      socket.add([27, 64, ...ascii.encode(text), 29, 86, 0]);
      await socket.flush().timeout(const Duration(seconds: 5));
      await socket.close().timeout(const Duration(seconds: 5));
      await store.db.update('print_jobs', {'status': 'enviado', 'error': null},
          where: 'id = ?', whereArgs: [jobId]);
    } catch (_) {
      if (jobId != null) {
        await store.db.update(
            'print_jobs',
            {
              'status': sending ? 'incerto' : 'falha',
              'error': sending
                  ? 'Envio interrompido. Confira o papel antes de reimprimir.'
                  : 'Não foi possível conectar à impressora. Confira IP, porta e energia.'
            },
            where: 'id = ?',
            whereArgs: [jobId]);
      }
    } finally {
      socket?.destroy();
      _busy = false;
    }
  }

  String _ascii(String text) {
    const from = 'áàâãäÁÀÂÃÄéèêëÉÈÊËíìîïÍÌÎÏóòôõöÓÒÔÕÖúùûüÚÙÛÜçÇ';
    const to = 'aaaaaAAAAAeeeeEEEEiiiiIIIIoooooOOOOOuuuuUUUUcC';
    return text.split('').map((c) {
      final i = from.indexOf(c);
      return i >= 0
          ? to[i]
          : c.codeUnitAt(0) < 128
              ? c
              : '?';
    }).join();
  }
}
