// lib/services/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/item_pedido.dart';

// Substitua pelo IP local do seu computador
const String baseUrl = 'http://localhost:5000';

class ApiService {
  // Método para obter itens de pedido com filtro de status
  Future<List<ItemPedido>> getItensPorStatus(String status) async {
    final response = await http.get(Uri.parse('$baseUrl/pedidos/itens?status_item=$status'));

    if (response.statusCode == 200) {
      List jsonResponse = jsonDecode(response.body);
      return jsonResponse.map((item) => ItemPedido.fromJson(item)).toList();
    } else {
      throw Exception('Falha ao carregar itens do pedido');
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