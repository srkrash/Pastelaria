// lib/services/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/item_pedido.dart';

// Substitua pelo IP local do seu computador
const String baseUrl = 'http://localhost:5000';

class ApiService {
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
}
