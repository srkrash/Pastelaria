// lib/screens/add_product_screen.dart
import 'package:flutter/material.dart';
import 'package:pastelaria_app/services/api_service.dart';
import 'package:pastelaria_app/models/item_pedido.dart';

class AddProductScreen extends StatefulWidget {
  final String productType;

  const AddProductScreen({super.key, required this.productType});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final ApiService _apiService = ApiService();
  late Future<List<dynamic>> _productsFuture;
  final Map<int, int> _quantidades = {}; // Map: id_produto -> quantidade

  @override
  void initState() {
    super.initState();
    _productsFuture = _apiService.getProdutos(tipo: widget.productType);
  }

  void _adicionarItem(int productId) {
    setState(() {
      _quantidades.update(productId, (value) => value + 1, ifAbsent: () => 1);
    });
  }

  void _removerItem(int productId) {
    if (_quantidades.containsKey(productId) && _quantidades[productId]! > 0) {
      setState(() {
        _quantidades.update(productId, (value) => value - 1);
      });
    }
  }

  void _confirmarSelecao(List<dynamic> products) {
    final List<ItemPedido> itensSelecionados = [];
    for (var product in products) {
      final int productId = product['id'];
      final String productName = product['nome'];
      final int quantidade = _quantidades[productId] ?? 0;
      
      if (quantidade > 0) {
        itensSelecionados.add(
          ItemPedido(
            id: productId, // Usamos o ID do produto para identificação
            quantidade: quantidade,
            produtoNome: productName,
            statusItem: 'aguardando', // Status inicial
            ingredientes: [], // Bebidas e salgados não têm ingredientes
            observacoesItem: '', // Sem observações por padrão
          ),
        );
      }
    }
    Navigator.of(context).pop(itensSelecionados);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Adicionar ${widget.productType}'),
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _productsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erro ao carregar produtos: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Nenhum produto encontrado.'));
          }

          final List<dynamic> products = snapshot.data!;

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final product = products[index];
                    final int quantidade = _quantidades[product['id']] ?? 0;

                    return ListTile(
                      title: Text(product['nome'], style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('R\$${product['preco']}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle),
                            onPressed: () => _removerItem(product['id']),
                          ),
                          Text('$quantidade', style: const TextStyle(fontSize: 20)),
                          IconButton(
                            icon: const Icon(Icons.add_circle),
                            onPressed: () => _adicionarItem(product['id']),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton(
                  onPressed: () => _confirmarSelecao(products),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                  ),
                  child: const Text('Adicionar ao Pedido'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}