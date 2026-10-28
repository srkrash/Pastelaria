import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'app_settings.dart';

class ApiException implements Exception {
  final String message;
  final int status;
  ApiException(this.message, this.status);
  @override
  String toString() => message;
}

class ApiService {
  Future<dynamic> request(String path, {Map<String, dynamic>? body}) async {
    final settings = await AppSettings.load();
    if (!settings.configured) {
      throw ApiException('Configure este tablet para conectar ao servidor.', 0);
    }
    final uri = Uri.parse('${settings.baseUrl}$path');
    final headers = {
      'Authorization': 'Bearer ${settings.secret}',
      'Content-Type': 'application/json; charset=utf-8'
    };
    final client = http.Client();
    try {
      final response = await (body == null
              ? client.get(uri, headers: headers)
              : client.post(uri, headers: headers, body: jsonEncode(body)))
          .timeout(const Duration(seconds: 10));
      dynamic data;
      try {
        data = jsonDecode(utf8.decode(response.bodyBytes));
      } on FormatException {
        throw ApiException(
            'Servidor incompatível ou resposta inválida. Confira o IP do tablet principal.',
            response.statusCode);
      }
      if (response.statusCode >= 400) {
        throw ApiException(data['erro'] as String? ?? 'Falha no servidor.',
            response.statusCode);
      }
      return data;
    } on TimeoutException {
      throw ApiException(
          'Servidor não respondeu. Confira a conexão; o comando pode ser reenviado sem duplicar.',
          0);
    } on http.ClientException {
      throw ApiException(
          'Conexão com o servidor interrompida. Confira o Wi-Fi e o tablet principal.',
          0);
    } on SocketException {
      throw ApiException(
          'Tablet principal inacessível. Confira a rede local.', 0);
    } finally {
      client.close();
    }
  }

  Future<Map<String, dynamic>> snapshot() async =>
      Map<String, dynamic>.from(await request('/snapshot') as Map);
  Future<Map<String, dynamic>> getPriceCatalog() async {
    try {
      return Map<String, dynamic>.from(
          await request('/catalogo/precos') as Map);
    } on ApiException catch (error) {
      if (error.status == 404) {
        throw ApiException(
            'Atualize primeiro o tablet principal para a versão 2.3.0 ou superior para carregar os preços.',
            404);
      }
      rethrow;
    }
  }

  Future<List<dynamic>> getPedidosHoje() async =>
      await request('/pedidos/hoje') as List;
  Future<Map<String, dynamic>> getBi(String from, String to) async =>
      Map<String, dynamic>.from(await request('/bi?from=$from&to=$to') as Map);
  Future<Map<String, dynamic>> getPedidoPorId(int id) async =>
      Map<String, dynamic>.from(await request('/pedidos/$id') as Map);
  Future<List<dynamic>> getProdutos({String? tipo}) async => await request(
          '/produtos${tipo == null ? '' : '?tipo=${Uri.encodeQueryComponent(tipo)}'}')
      as List;
  Future<Map<String, dynamic>> command(
      String action, Map<String, dynamic> payload,
      {String? commandId}) async {
    final body = {
      'command_id': commandId ?? newCommandId(),
      'action': action,
      'payload': payload
    };
    try {
      return Map<String, dynamic>.from(
          await request('/commands', body: body) as Map);
    } on ApiException catch (e) {
      if (e.status != 0) rethrow;
      return Map<String, dynamic>.from(
          await request('/commands', body: body) as Map);
    }
  }

  Future<String> _serverBinding() async {
    final s = await AppSettings.load();
    return sha256.convert(utf8.encode('${s.baseUrl}:${s.secret}')).toString();
  }

  Future<Map<String, dynamic>> inserirPedido(
      String endpoint, Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = Map<String, dynamic>.from(data)..remove('command_id');
    final pendingText = prefs.getString('pending_create_v2');
    final binding = await _serverBinding();
    Map<String, dynamic> pending;
    if (pendingText != null) {
      pending = jsonDecode(pendingText) as Map<String, dynamic>;
      if (pending['server'] != binding ||
          jsonEncode(pending['payload']) != jsonEncode(payload)) {
        throw ApiException(
            'Há uma confirmação anterior pendente. Resolva em Configurações antes de criar outro pedido.',
            409);
      }
    } else {
      pending = {
        'id': data['command_id'] ?? newCommandId(),
        'payload': payload,
        'server': binding
      };
      await prefs.setString('pending_create_v2', jsonEncode(pending));
    }
    return _sendPending(pending);
  }

  Future<Map<String, dynamic>?> pendingOrder() async {
    final text =
        (await SharedPreferences.getInstance()).getString('pending_create_v2');
    return text == null ? null : jsonDecode(text) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> recoverPending() async {
    final pending = await pendingOrder();
    if (pending == null) {
      throw ApiException('Nenhuma confirmação pendente.', 404);
    }
    if (pending['server'] != await _serverBinding()) {
      throw ApiException(
          'Volte à configuração do servidor original para resolver o pedido pendente.',
          409);
    }
    return _sendPending(pending);
  }

  Future<Map<String, dynamic>> _sendPending(
      Map<String, dynamic> pending) async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final result = await command(
          'create', Map<String, dynamic>.from(pending['payload'] as Map),
          commandId: pending['id'] as String);
      await prefs.remove('pending_create_v2');
      return result;
    } on ApiException catch (e) {
      if (e.status == 400 ||
          e.status == 410 ||
          e.status == 413 ||
          e.status == 422) {
        await prefs.remove('pending_create_v2');
      }
      rethrow;
    }
  }

  Future<void> changeQuantity(
      Map<String, dynamic> order, int itemId, int count, bool production,
      {String? commandId}) async {
    await command(
        production ? 'ready' : 'deliver',
        {
          'pedido_id': order['pedido_id'],
          'item_id': itemId,
          'quantidade': count,
          'expected_revision': order['revision']
        },
        commandId: commandId);
  }

  Future<void> deliverOrder(Map<String, dynamic> order,
      {String? commandId}) async {
    await command(
        'deliver_all',
        {
          'pedido_id': order['pedido_id'],
          'expected_revision': order['revision'],
        },
        commandId: commandId);
  }

  Future<bool> updatePedidoStatus(int id, String status) async {
    if (status != 'cancelado') {
      throw ApiException(
          'Use a fila de entrega para conferir e entregar as quantidades prontas.',
          400);
    }
    final order = await getPedidoPorId(id);
    await command(
        'cancel', {'pedido_id': id, 'expected_revision': order['revision']});
    return true;
  }

  Future<void> reimprimirPedido(int id) async {
    final order = await getPedidoPorId(id);
    await command(
        'reprint', {'pedido_id': id, 'expected_revision': order['revision']});
  }

  Future<List<dynamic>> printJobs() async =>
      await request('/print-jobs') as List;
}
