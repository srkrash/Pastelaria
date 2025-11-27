import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/item_pedido.dart';
import 'ip_storage.dart';

class ApiService {
  Future<String> _getBaseUrl() async {
    final ip = await IpStorage.getIp() ?? 'localhost';
    return 'http://$ip:5000';
  }

  Future<List<dynamic>> getPedidosHoje() async {
    final baseUrl = await _getBaseUrl();
    final url = Uri.parse('$baseUrl/pedidos/hoje');
    try {
      debugPrint('ApiService: GET $url');
      final response = await http.get(url);
      debugPrint('ApiService: Response ${response.statusCode}');
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Falha ao carregar pedidos: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('ApiService: Erro em getPedidosHoje: $e');
      throw Exception('Erro ao conectar com a API: $e');
    }
  }

  Future<Map<String, dynamic>> getPedidoPorId(int idPedido) async {
    final baseUrl = await _getBaseUrl();
    final url = Uri.parse('$baseUrl/pedidos/$idPedido');
    try {
      debugPrint('ApiService: GET $url');
      final response = await http.get(url);
      debugPrint('ApiService: Response ${response.statusCode}');
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else if (response.statusCode == 404) {
        throw Exception('Pedido não encontrado.');
      } else {
        throw Exception('Falha ao carregar o pedido: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<List<ItemPedido>> getItensPorStatus(List<String> statuses) async {
    final baseUrl = await _getBaseUrl();
    try {
      final statusQuery = statuses.map((s) => 'status_item=$s').join('&');
      final uri = Uri.parse('$baseUrl/pedidos/itens?$statusQuery');

      debugPrint('ApiService: GET $uri');
      final response = await http.get(uri);
      debugPrint('ApiService: Response ${response.statusCode}');

      if (response.statusCode == 200) {
        List<dynamic> itensJson = json.decode(response.body);
        return itensJson.map((json) => ItemPedido.fromJson(json)).toList();
      } else {
        throw Exception('Falha ao buscar itens com status: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('ApiService: Erro em getItensPorStatus: $e');
      throw Exception('Erro ao buscar itens: $e');
    }
  }

  Future<void> atualizarStatusItem(int itemId, String novoStatus) async {
    final baseUrl = await _getBaseUrl();
    final uri = Uri.parse('$baseUrl/itens-pedido/$itemId/status');
    debugPrint('ApiService: PUT $uri -> $novoStatus');
    final response = await http.put(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'status': novoStatus}),
    );
    debugPrint('ApiService: Response ${response.statusCode}');

    if (response.statusCode != 200) {
      throw Exception('Falha ao atualizar o status do item');
    }
  }

  Future<Map<String, dynamic>> inserirPedido(String endpoint, Map<String, dynamic> data) async {
    final baseUrl = await _getBaseUrl();
    final uri = Uri.parse('$baseUrl/$endpoint');
    debugPrint('ApiService: POST $uri');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json; charset=UTF-8'},
      body: jsonEncode(data),
    );
    debugPrint('ApiService: Response ${response.statusCode}');

    if (response.statusCode == 201) {
      return json.decode(response.body);
    } else {
      throw Exception('Falha ao enviar dados para $endpoint: ${response.statusCode}');
    }
  }

  Future<List<dynamic>> getProdutos({String? tipo}) async {
    final baseUrl = await _getBaseUrl();
    try {
      String endpoint = 'produtos';
      if (tipo != null && tipo.isNotEmpty) {
        endpoint = '$endpoint?tipo=$tipo';
      }

      final url = Uri.parse('$baseUrl/$endpoint');
      debugPrint('ApiService: GET $url');
      final response = await http.get(url);
      debugPrint('ApiService: Response ${response.statusCode}');

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Falha ao carregar produtos: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> updatePedidoStatus(int pedidoId, String newStatus) async {
    final baseUrl = await _getBaseUrl();
    final url = Uri.parse('$baseUrl/pedidos/$pedidoId/status');

    try {
      debugPrint('ApiService: PATCH $url -> $newStatus');
      final response = await http.patch(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'status': newStatus}),
      );
      debugPrint('ApiService: Response ${response.statusCode}');

      if (response.statusCode == 200) {
        return true;
      } else {
        String msg = 'Falha na atualização do status.';
        try {
          final err = json.decode(response.body);
          msg = err['erro'] ?? msg;
        } catch (_) {}
        throw Exception(msg);
      }
    } catch (e) {
      throw Exception('Erro ao conectar com o servidor: $e');
    }
  }

  Future<List<dynamic>> getFilaEntrega() async {
    final baseUrl = await _getBaseUrl();
    final url = Uri.parse('$baseUrl/fila_entrega');
    try {
      debugPrint('ApiService: GET $url');
      final response = await http.get(url);
      debugPrint('ApiService: Response ${response.statusCode}');

      if (response.statusCode == 200) {
        return json.decode(response.body) as List<dynamic>;
      } else {
        throw Exception('Falha ao carregar fila: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Erro de conexão ao buscar fila: $e');
    }
  }

  Future<void> reimprimirPedido(int pedidoId) async {
    final baseUrl = await _getBaseUrl();
    final url = Uri.parse('$baseUrl/reimprimir_pedido/$pedidoId');
    debugPrint('ApiService: POST $url');

    try {
      final response = await http.post(url);
      debugPrint('ApiService: Response ${response.statusCode}');

      if (response.statusCode != 200) {
        throw Exception('Falha ao solicitar reimpressão: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('ApiService: Erro em reimprimirPedido: $e');
      throw Exception('Erro ao conectar com a API: $e');
    }
  }
}
