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
    // Carrega os produtos baseados no tipo (ex: 'Bebidas' ou 'Salgados')
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
      final double preco = double.tryParse(product['preco']?.toString() ?? '0.0') ?? 0.0;
      
      if (quantidade > 0) {
        itensSelecionados.add(
          ItemPedido(
            id: productId, // Usamos o ID do produto para identificação
            pedidoId: 0, // Placeholder
            quantidade: quantidade,
            produtoNome: productName,
            statusItem: 'pronto', // Status inicial
            preco: preco,
            ingredientes: [], // Bebidas e salgados não têm ingredientes
            observacoesItem: '', // Sem observações por padrão
          ),
        );
      }
    }
    // Retorna a lista de ItemPedido para a tela anterior
    Navigator.of(context).pop(itensSelecionados);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Adicionar ${widget.productType}'),
        backgroundColor: Colors.deepOrange, // Tema da Pastelaria
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
          // Verifica se há algum item com quantidade maior que zero
          final bool hasSelectedItems = _quantidades.values.any((qty) => qty > 0);

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final product = products[index];
                    final int idProduto = product['id'];
                    final int quantidade = _quantidades[idProduto] ?? 0;
                    final double preco = (product['preco'] as num? ?? 0.0).toDouble();
                    
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      title: Text(product['nome'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      subtitle: Text('R\$${preco.toStringAsFixed(2)}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Botão de remover (desabilitado se a quantidade for 0)
                          IconButton(
                            icon: Icon(Icons.remove_circle, color: quantidade > 0 ? Colors.deepOrange : Colors.grey.shade400),
                            onPressed: quantidade > 0 ? () => _removerItem(idProduto) : null,
                          ),
                          Container(
                            width: 30,
                            alignment: Alignment.center,
                            child: Text('$quantidade', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          ),
                          // Botão de adicionar
                          IconButton(
                            icon: const Icon(Icons.add_circle, color: Colors.deepOrange),
                            onPressed: () => _adicionarItem(idProduto),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              // Botão de Confirmação
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton(
                  // Botão só é clicável se houver itens selecionados
                  onPressed: hasSelectedItems ? () => _confirmarSelecao(products) : null,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    backgroundColor: Colors.deepOrange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
