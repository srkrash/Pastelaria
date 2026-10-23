import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'order_store.dart';

class LocalServer {
  final OrderStore store;
  final String secret;
  HttpServer? _server;
  final Set<WebSocket> _clients = {};
  LocalServer(this.store, this.secret);
  int get port => _server!.port;

  Future<void> start({InternetAddress? address, int port = 5000}) async {
    if (secret.length < 16) throw StateError('Chave de conexão inválida.');
    _server = await HttpServer.bind(address ?? InternetAddress.anyIPv4, port,
        shared: false);
    _server!.listen((request) {
      unawaited(_handle(request));
    });
  }

  Future<void> stop() async {
    for (final ws in _clients.toList()) {
      await ws.close();
    }
    _clients.clear();
    await _server?.close(force: true);
    _server = null;
  }

  Future<void> _handle(HttpRequest r) async {
    var upgraded = false;
    try {
      if (r.headers.value(HttpHeaders.authorizationHeader) !=
          'Bearer $secret') {
        throw BusinessError(
            'Chave de conexão inválida. Confira as configurações.', 401);
      }
      if (r.uri.path == '/events' && WebSocketTransformer.isUpgradeRequest(r)) {
        final ws = await WebSocketTransformer.upgrade(r);
        upgraded = true;
        ws.pingInterval = const Duration(seconds: 15);
        _clients.add(ws);
        ws.listen((_) {},
            onDone: () => _clients.remove(ws),
            onError: (_) => _clients.remove(ws));
        ws.add(jsonEncode({'type': 'refresh'}));
        return;
      }
      final path = r.uri.pathSegments;
      dynamic result;
      var status = 200;
      if (r.method == 'GET' && r.uri.path == '/health') {
        result = {'protocol': 2, 'server': 'pastelaria-tablet'};
      } else if (r.method == 'GET' && r.uri.path == '/produtos') {
        result = await store.products(r.uri.queryParameters['tipo']);
      } else if (r.method == 'GET' && r.uri.path == '/snapshot') {
        result = await store.snapshot(activeOnly: true);
      } else if (r.method == 'GET' && r.uri.path == '/pedidos/hoje') {
        result = (await store.snapshot(today: true))['pedidos'];
      } else if (r.method == 'GET' &&
          path.length == 2 &&
          path.first == 'pedidos') {
        result = await store.order(int.parse(path.last));
      } else if (r.method == 'GET' && r.uri.path == '/print-jobs') {
        result =
            await store.db.query('print_jobs', orderBy: 'id DESC', limit: 50);
      } else if (r.method == 'POST' && r.uri.path == '/commands') {
        var size = 0;
        final bytes = <int>[];
        await for (final chunk in r) {
          size += chunk.length;
          if (size > 1024 * 1024) {
            throw BusinessError('Pedido muito grande.', 413);
          }
          bytes.addAll(chunk);
        }
        final body = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
        result = await store.command(
            body['command_id'] as String,
            body['action'] as String,
            Map<String, dynamic>.from(body['payload'] as Map));
        status = 200;
        for (final ws in _clients.toList()) {
          try {
            ws.add(jsonEncode({'type': 'refresh'}));
          } catch (_) {
            _clients.remove(ws);
          }
        }
      } else {
        throw BusinessError('Recurso não encontrado.', 404);
      }
      r.response.statusCode = status;
      r.response.headers.contentType = ContentType.json;
      r.response.write(jsonEncode(result));
    } on BusinessError catch (e) {
      r.response.statusCode = e.status;
      r.response.headers.contentType = ContentType.json;
      r.response.write(jsonEncode({'erro': e.message}));
    } on FormatException {
      r.response.statusCode = 400;
      r.response.write(jsonEncode({'erro': 'Dados inválidos.'}));
    } on TypeError {
      r.response.statusCode = 400;
      r.response.write(jsonEncode({'erro': 'Campos obrigatórios inválidos.'}));
    } catch (_) {
      r.response.statusCode = 500;
      r.response.write(jsonEncode({
        'erro': 'Falha interna; nenhuma confirmação de sucesso foi emitida.'
      }));
    } finally {
      if (!upgraded) await r.response.close();
    }
  }
}
