import 'dart:async';
import 'dart:io';
import 'order_store.dart';
import 'receipt_encoder.dart';
import 'pix_payment.dart';

/// Failed/ambiguous jobs require operator review, never an automatic resend.
class PrinterWorker {
  final OrderStore store;
  final String host;
  final int port;
  final PixConfiguration? pix;
  Timer? _timer;
  bool _busy = false;
  Future<void>? _active;
  PrinterWorker(this.store, this.host, this.port, {this.pix});
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
      final bytes =
          encodeReceipt(order, secondCopy: job['second_copy'] == 1, pix: pix);
      sending = true;
      socket.add(bytes);
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
}
