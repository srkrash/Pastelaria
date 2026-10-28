import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pastelaria_app/server/order_store.dart';
import 'package:pastelaria_app/server/printer_worker.dart';
import 'package:pastelaria_app/server/receipt_encoder.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timezone/data/latest.dart' as tz;

Map<String, dynamic> receipt({int items = 1, String note = ''}) => {
      'id': 123,
      'numero_pedido': 99,
      'data_hora_pedido': '2026-10-28T18:00:00Z',
      'observacoes': note,
      'total_centavos': 12345,
      'itens': List.generate(
          items,
          (i) => {
                'quantidade': 2,
                'produto_nome': 'Pastel $i',
                'ingredientes': ['Carne', 'Queijo'],
                'observacoes_item': 'Sem cebola $i',
              }),
    };

void main() {
  test('pedido longo preserva último item e total antes de avançar e cortar',
      () {
    final bytes = encodeReceipt(receipt(items: 100));
    final body = ascii.decode(bytes.sublist(2, bytes.length - 4));
    expect(body, contains('2x Pastel 99\n'));
    expect(body, contains('OBS: Sem cebola 99\n'));
    expect(body, contains('TOTAL: R\$ 123,45\n'));
    expect(body, contains('Obrigado pela compra, volte sempre!\n\n'));
    // TP-650: partial cut with feed; full-cut mode 0 is not documented.
    expect(bytes.sublist(bytes.length - 4), [29, 86, 66, 0]);
    expect(body.split('\x1dV').length, 1); // no cut inside the receipt
  });

  test('texto não pode injetar corte ou reset; conserva linhas e acentos ASCII',
      () {
    final order = receipt(note: 'Viagem\r\nAtenção\rFim\x1dV\x00\x1b@');
    order['itens'][0]['produto_nome'] = 'Água\x1dV\x00';
    order['itens'][0]['ingredientes'] = ['Queijo\x1b@'];
    order['itens'][0]['observacoes_item'] = 'OBS\x1dV\x00';
    final bytes = encodeReceipt(order, secondCopy: true);
    final body = bytes.sublist(2, bytes.length - 4);
    expect(ascii.decode(body), isNot(contains('\x1dV\x00')));
    expect(ascii.decode(body), isNot(contains('\x1b@')));
    expect(ascii.decode(body), contains('Viagem\nAtencao\nFim?V??@'));
    expect(ascii.decode(body), contains('*** SEGUNDA VIA ***'));
    expect(ascii.decode(body), contains('Agua?V?'));
  });

  test('layout centraliza título e destaca pedido sem alterar data e itens',
      () {
    final order = receipt(note: 'Viagem');
    order['numero_pedido'] = 10;
    order['data_hora_pedido'] = '2026-10-28T19:40:00Z';
    final raw = ascii.decode(encodeReceipt(order));
    expect(raw,
        startsWith('\x1b@\x1ba\x01PASTELARIA GAUCHA\n\x1ba\x00${'-' * 48}\n'));
    expect(
        raw,
        contains(
            '\x1bE\x01\x1d!\x11PEDIDO: 10\n\x1d!\x00\x1bE\x00Data: 28/10/2026 16:40\n'));
    expect(raw.indexOf('OBSERVACAO DO PEDIDO:'),
        greaterThan(raw.indexOf('TOTAL:')));
    expect(
        raw.indexOf('Viagem'), lessThan(raw.indexOf('Obrigado pela compra')));
    expect(raw, isNot(contains('PEDIDO INTERNO:')));
    order['numero_pedido'] = -1;
    expect(ascii.decode(encodeReceipt(order)), contains('PEDIDO: BALCAO\n'));
  });

  setUpAll(() {
    sqfliteFfiInit();
    tz.initializeTimeZones();
  });

  test('worker envia pedido longo completo a receptor TCP independente',
      () async {
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath,
        options:
            OpenDatabaseOptions(version: 1, onCreate: OrderStore.createSchema));
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final received = Completer<List<int>>();
    var connections = 0;
    final subscription = server.listen((socket) {
      connections++;
      final bytes = <int>[];
      socket.listen(bytes.addAll, onDone: () {
        if (!received.isCompleted) received.complete(bytes);
        socket.destroy();
      }, onError: (Object error) {
        if (!received.isCompleted) received.completeError(error);
        socket.destroy();
      });
    });
    final store = OrderStore(db);
    final worker = PrinterWorker(store, '127.0.0.1', server.port);
    try {
      await store.seed([
        {'nome': 'Água', 'tipo': 'bebida', 'preco_centavos': 200},
      ]);
      final order = await store.command('synthetic-print', 'create', {
        'observacoes_pedido':
            List.filled(3000, 'Observacao sintetica').join('\n'),
        'itens': [
          {'produto_nome': 'Água', 'quantidade': 1},
        ],
      });
      await worker.start();
      final bytes = await received.future.timeout(const Duration(seconds: 10));
      await worker.stop();
      expect(bytes.length, greaterThan(60000));
      expect(bytes, encodeReceipt(order));
      expect((await db.query('print_jobs')).single['status'], 'enviado');
      expect((await db.query('orders')), hasLength(1));
      expect(connections, 1);
    } finally {
      await worker.stop();
      await subscription.cancel();
      await server.close();
      await db.close();
    }
  });
}
