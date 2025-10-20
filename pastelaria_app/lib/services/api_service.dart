// lib/services/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/item_pedido.dart';

// Substitua pelo IP local do seu computador
const String baseUrl = 'http://localhost:5000';

class ApiService {
  Future<List<dynamic>> getPedidosHoje() async {
    final url = Uri.parse('$baseUrl/pedidos/hoje');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Falha ao carregar pedidos: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Erro ao conectar com a API: $e');
    }
  }

Future<Map<String, dynamic>> getPedidoPorId(int idPedido) async {
    final url = Uri.parse('$baseUrl/pedidos/$idPedido');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else if (response.statusCode == 404) {
         throw Exception('Pedido não encontrado.');
      }
      else {
        throw Exception('Falha ao carregar o pedido: ${response.statusCode}');
      }
    } catch (e) {
      rethrow; 
    }
  }

  // Método para obter itens de pedido com filtro de status
  Future<List<ItemPedido>> getItensPorStatus(List<String> statuses) async {
    try {
      final statusQuery = statuses.map((s) => 'status_item=$s').join('&');
      final uri = Uri.parse('$baseUrl/pedidos/itens?$statusQuery');

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        List<dynamic> itensJson = json.decode(response.body);
        return itensJson.map((json) => ItemPedido.fromJson(json)).toList();
      } else {
        throw Exception(
            'Falha ao buscar itens com status: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Erro ao buscar itens: $e');
    }
  }

  // Método para atualizar o status de um item
  Future<void> atualizarStatusItem(int itemId, String novoStatus) async {
    final response = await http.put(
      Uri.parse('$baseUrl/itens-pedido/$itemId/status'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'status': novoStatus}),
    );

    if (response.statusCode != 200) {
      throw Exception('Falha ao atualizar o status do item');
    }
  }

  Future<Map<String, dynamic>> inserirPedido(String endpoint, Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/$endpoint'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(data),
    );

    if (response.statusCode == 201) { // 201 Created
      return json.decode(response.body);
    } else {
      throw Exception('Falha ao enviar dados para o endpoint: $endpoint. Status: ${response.statusCode}');
    }
  }

  Future<List<dynamic>> getProdutos({String? tipo}) async {

    try {
      String endpoint = 'produtos';
      // Se um tipo for fornecido, adiciona-o como um parâmetro de consulta.
      if (tipo != null && tipo.isNotEmpty) {
        endpoint = '$endpoint?tipo=$tipo';
      }

      final url = Uri.parse('$baseUrl/$endpoint');

      // Faz a requisição GET.
      final response = await http.get(url);

      if (response.statusCode == 200) {
        // Decodifica o corpo da resposta JSON para uma lista dinâmica.
        return jsonDecode(response.body);
      } else {
        // Lança uma exceção se a requisição falhar.
        throw Exception(
            'Falha ao carregar produtos: Status Code ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> updatePedidoStatus(int pedidoId, String newStatus) async {
    final url = Uri.parse('$baseUrl/pedidos/$pedidoId/status');
    
    final body = json.encode({
      'status': newStatus,
    });

    try {
      final response = await http.patch(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: body,
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        String errorMessage = 'Falha na atualização do status.';
        try {
          final errorData = json.decode(response.body);
          errorMessage = errorData['erro'] ?? errorMessage;
        } catch (_) {}
        
        throw Exception(errorMessage);
      }
    } catch (e) {
      throw Exception('Erro ao conectar com o servidor para atualizar status: $e');
    }
  }

  Future<List<dynamic>> getFilaEntrega() async {
    final url = Uri.parse('$baseUrl/fila_entrega'); // Assumindo o endpoint Flask: /fila_entrega
    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        // A API deve retornar uma lista de pedidos (Map)
        return json.decode(response.body) as List<dynamic>; 
      } else {
        throw Exception('Falha ao carregar a fila de entrega: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Erro de conexão ao buscar fila de entrega: $e');
    }
  }

}