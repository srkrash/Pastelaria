import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:pastelaria_app/providers/pedidos_provider.dart';
import 'package:pastelaria_app/screens/add_pastel_screen.dart';
import 'package:pastelaria_app/screens/add_product_screen.dart';
import 'package:pastelaria_app/models/item_pedido.dart';
import 'package:pastelaria_app/services/api_service.dart';
import 'package:pastelaria_app/services/app_settings.dart';
import 'dart:convert';

class NovoPedidoScreen extends StatefulWidget {
  const NovoPedidoScreen({super.key});

  @override
  State<NovoPedidoScreen> createState() => _NovoPedidoScreenState();
}

class _NovoPedidoScreenState extends State<NovoPedidoScreen> {
  bool _isLoading = false;
  // Instancia o serviço de API
  final ApiService _apiService = ApiService();
  final TextEditingController _observacoesController = TextEditingController();
  String? _submittedFingerprint;
  String _commandId = newCommandId();

  @override
  void dispose() {
    _observacoesController.dispose();
    super.dispose();
  }

  // Método para navegar e adicionar itens do pastel customizado
  void _navigateAndAddItem(BuildContext context) async {
    final PedidosProvider pedidosProvider =
        Provider.of<PedidosProvider>(context, listen: false);

    // Navega e espera o resultado da tela de adição de pastel (AddPastelScreen)
    final resultado = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AddPastelScreen(),
      ),
    );

    if (resultado != null) {
      final quantidade = resultado['quantidade'] as int;
      final ingredientes = resultado['ingredientes'] as List<String>;
      final observacoes = resultado['observacoesItem'] as String;

      // Nome padrão para o pastel customizado
      String produtoNome = 'Pastel';

      // Cria o novo item e adiciona ao pedido
      final novoItem = ItemPedido(
        id: 0,
        pedidoId: 0, // Placeholder para novo pedido
        numeroPedido: 0, // Temporário
        quantidade: quantidade,
        produtoNome: produtoNome,
        statusItem: 'aguardando',
        // O preço é 0.0 aqui, pois será calculado dinamicamente no _calcularSubtotal
        preco: 0.0,
        ingredientes: ingredientes,
        observacoesItem: observacoes,
      );

      pedidosProvider.adicionarItem(novoItem);
    }
  }

  // Método para navegar e adicionar produtos simples (bebidas, salgados)
  void _navigateAndAddProducts(BuildContext context, String productType) async {
    final pedidosProvider =
        Provider.of<PedidosProvider>(context, listen: false);

    final resultado = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AddProductScreen(productType: productType),
      ),
    );

    if (resultado != null && resultado is List<ItemPedido>) {
      for (var item in resultado) {
        pedidosProvider.adicionarItem(item);
      }
    }
  }

  // Função auxiliar para calcular o preço de um pastel específico (baseado na sua lógica)
  double _calcularPrecoPastel(ItemPedido item) {
    // Ingredientes gratuitos que não contam como 'extra'
    final List<String> ingredientesGratuitos = [
      'Cebola',
      'Cebolinha',
      'Orégano'
    ];

    // Caso especial 1: Pastel de Pizza (preço fixo)
    if (item.ingredientes.length == 1 && item.ingredientes.first == 'Pizza') {
      return 15.00 * item.quantidade;
      // Caso especial 2: Pastel Misto (preço fixo)
    } else if (item.ingredientes.length == 1 &&
        item.ingredientes.first == 'Misto') {
      return 25.00 * item.quantidade;
    } else {
      // Lógica para pastéis customizados.

      // Filtra os ingredientes que são pagos
      final List<String> ingredientesPagos = item.ingredientes
          .where((ing) => !ingredientesGratuitos.contains(ing))
          .toList();

      double precoBase = 12.00; // Preço base do pastel
      int numIngredientesPagos = ingredientesPagos.length;

      // Cobra R$ 3,00 por ingrediente pago acima de 2
      if (numIngredientesPagos > 2) {
        precoBase += (numIngredientesPagos - 2) * 3.00;
      }
      return precoBase * item.quantidade;
    }
  }

  // A função principal de cálculo do subtotal do pedido.
  double _calcularSubtotal() {
    double total = 0.0;
    // Usa listen: false pois esta função é chamada dentro de build e não precisa de rebuilds internos
    for (var item in Provider.of<PedidosProvider>(context, listen: false)
        .itensPedidoAtual) {
      if (item.produtoNome == 'Pastel') {
        // Delega o cálculo do preço do pastel
        total += _calcularPrecoPastel(item);
      } else {
        // Usa o preço direto para salgados e bebidas.
        total += (item.preco) * item.quantidade;
      }
    }
    return total;
  }

  // Função para confirmar o pedido usando o ApiService
  Future<void> _confirmarPedido(PedidosProvider pedidosProvider) async {
    if (_isLoading) return;
    if (pedidosProvider.itensPedidoAtual.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Adicione pelo menos um item para confirmar o pedido.')),
      );
      return;
    }

    // Exibe o diálogo para escolher entre Consumo ou Viagem
    String? tipoPedido = await showDialog<String>(
      context: context,
      barrierDismissible: false, // Obriga o usuário a escolher
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Tipo de Pedido',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          content: const Text('O pedido é para consumo no local ou viagem?',
              style: TextStyle(fontSize: 24)),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.orange,
                padding:
                    const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
              ),
              child: const Text('CONSUMO',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
              onPressed: () {
                Navigator.of(context).pop('Consumo');
              },
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.blue,
                padding:
                    const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
              ),
              child: const Text('VIAGEM',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
              onPressed: () {
                Navigator.of(context).pop('Viagem');
              },
            ),
            TextButton(
              child: const Text('Cancelar',
                  style: TextStyle(color: Colors.grey, fontSize: 20)),
              onPressed: () {
                Navigator.of(context).pop(null); // Retorna null se cancelar
              },
            ),
          ],
        );
      },
    );

    // Se o usuário cancelou o diálogo (retornou null), não prossegue
    if (tipoPedido == null) return;
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    final double valorTotal = _calcularSubtotal();

    // Mapeia os itens para o formato esperado pelo payload da API
    final List<Map<String, dynamic>> itensData =
        pedidosProvider.itensPedidoAtual.map((item) {
      return {
        'produto_nome': item.produtoNome,
        'quantidade': item.quantidade,
        'ingredientes': item.ingredientes
            .map((ing) => {'nome': ing, 'quantidade': 1})
            .toList(),
        'observacoes_item': item.observacoesItem,
      };
    }).toList();

    // Formata a observação com o prefixo do tipo de pedido
    String observacoesFinais = "[$tipoPedido] ${_observacoesController.text}";

    // Monta o payload completo
    final pedidoPayload = {
      'valor_total': valorTotal,
      'observacoes_pedido': observacoesFinais,
      'itens': itensData,
    };

    final fingerprint = jsonEncode(pedidoPayload);
    if (_submittedFingerprint != fingerprint) {
      _submittedFingerprint = fingerprint;
      _commandId = newCommandId();
    }
    pedidoPayload['command_id'] = _commandId;

    try {
      final response =
          await _apiService.inserirPedido('pedidos', pedidoPayload);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Pedido #${response['numero_pedido']} confirmado com sucesso!')),
      );

      // Atualiza o estado do último pedido no Provider
      pedidosProvider.setUltimoPedido(response['numero_pedido'] as int,
          (response['total_pedido'] as num).toDouble());

      // Limpa o pedido atual e volta para a tela anterior
      pedidosProvider.limparPedido();
      await pedidosProvider.refresh();
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao confirmar pedido: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Widget auxiliar para os botões de categoria
  Widget _buildCategoryButton(BuildContext context,
      {required String text, required VoidCallback onPressed}) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.amber.shade700, // Cor de pastel!
        foregroundColor: const Color.fromARGB(183, 0, 0, 0),
        padding: const EdgeInsets.symmetric(vertical: 32), // Slight increase
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
            fontSize: 22, fontWeight: FontWeight.bold), // Slight increase
      ),
    );
  }

  // Widget auxiliar para a barra inferior (Cancelar e Confirmar)
  Widget _buildBottomBar(
      BuildContext context, PedidosProvider pedidosProvider, bool canConfirm) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _isLoading
                  ? null
                  : () {
                      pedidosProvider.limparPedido();
                      Navigator.of(context)
                          .pop(); // Volta para a tela de navegação
                    },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                    vertical: 35), // Significant increase
                side: const BorderSide(color: Colors.red),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Cancelar Pedido',
                  style: TextStyle(
                      fontSize: 28,
                      color: Colors.red,
                      fontWeight: FontWeight.bold)), // Significant increase
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed:
                  canConfirm ? () => _confirmarPedido(pedidosProvider) : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    vertical: 35), // Significant increase
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 30,
                      height: 30,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 3),
                    )
                  : const Text('Confirmar Pedido',
                      style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold)), // Significant increase
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Observa o Provider para reconstruir a lista de itens e o subtotal
    final pedidosProvider = Provider.of<PedidosProvider>(context);
    final bool canConfirm =
        pedidosProvider.itensPedidoAtual.isNotEmpty && !_isLoading;

    final double subtotal = _calcularSubtotal();
    final String subtotalFormatado =
        NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(subtotal);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Novo Pedido (Montagem)'),
        backgroundColor: Colors.deepOrange,
      ),
      body: Column(
        children: [
          // Área dos botões de categoria
          Container(
            color: Colors.grey[100],
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildCategoryButton(
                  context,
                  text: 'Inserir Pastel', // Updated text
                  onPressed: () => _navigateAndAddItem(context),
                ),
                const SizedBox(height: 8.0),
                Row(
                  children: [
                    Expanded(
                      child: _buildCategoryButton(
                        context,
                        text: 'Inserir Bebida', // Updated text
                        onPressed: () =>
                            _navigateAndAddProducts(context, 'bebida'),
                      ),
                    ),
                    const SizedBox(width: 8.0),
                    Expanded(
                      child: _buildCategoryButton(
                        context,
                        text: 'Inserir Salgado', // Updated text
                        onPressed: () =>
                            _navigateAndAddProducts(context, 'salgado'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Área da Lista de Itens (Comanda)
          Expanded(
            child: Container(
              color: const Color.fromARGB(235, 255, 255, 255),
              child: pedidosProvider.itensPedidoAtual.isEmpty
                  ? const Center(
                      child: Text('Nenhum item adicionado à comanda.',
                          style: TextStyle(
                              fontSize: 24,
                              color: Colors.blueGrey) // Increased size
                          ),
                    )
                  : ListView.builder(
                      itemCount: pedidosProvider.itensPedidoAtual.length,
                      itemBuilder: (context, index) {
                        final item = pedidosProvider.itensPedidoAtual[index];
                        // Calcula o preço individual do item para exibição na lista
                        final itemPreco = item.produtoNome == 'Pastel'
                            ? _calcularPrecoPastel(item)
                            : item.preco * item.quantidade;
                        final itemPrecoFormatado = NumberFormat.currency(
                                locale: 'pt_BR', symbol: 'R\$')
                            .format(itemPreco);

                        return Container(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8), // Increased vertical margin
                          decoration: BoxDecoration(
                            border: Border(
                                bottom:
                                    BorderSide(color: Colors.grey.shade200)),
                          ),
                          child: ListTile(
                            leading: Text('${item.quantidade}x',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 22)), // Increased size
                            title: Text(item.produtoNome,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 26) // Increased size
                                ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Exibe os ingredientes se for um pastel customizado
                                if (item.ingredientes.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: Text(
                                        'Ingredientes: ${item.ingredientes.join(', ')}',
                                        style: const TextStyle(
                                            fontStyle: FontStyle.italic,
                                            fontSize: 20) // Increased size
                                        ),
                                  ),
                                // Exibe as observações
                                if (item.observacoesItem.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: Text('OBS: ${item.observacoesItem}',
                                        style: TextStyle(
                                            fontStyle: FontStyle.normal,
                                            fontSize: 20,
                                            color: Colors
                                                .red.shade700) // Increased size
                                        ),
                                  ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(itemPrecoFormatado,
                                    style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight:
                                            FontWeight.bold)), // Increased size
                                IconButton(
                                  icon: const Icon(Icons.delete_forever,
                                      color: Colors.red,
                                      size: 32), // Increased icon size
                                  onPressed: () {
                                    pedidosProvider.removerItem(item);
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),

          // Rodapé fixo com Subtotal
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withValues(alpha: 0.3),
                  spreadRadius: 1,
                  blurRadius: 5,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Subtotal:',
                    style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.black)), // Increased size
                Text(subtotalFormatado,
                    style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepOrange.shade700) // Increased size
                    ),
              ],
            ),
          ),

          // Campo de Observações
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            color: Colors.white,
            child: TextField(
              controller: _observacoesController,
              style: const TextStyle(fontSize: 20), // Increased input text size
              decoration: const InputDecoration(
                labelText: 'Observações do Pedido',
                labelStyle: TextStyle(fontSize: 20), // Increased label size
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.note, size: 28), // Increased icon size
              ),
              maxLines: 2,
            ),
          ),
        ],
      ),
      bottomNavigationBar:
          _buildBottomBar(context, pedidosProvider, canConfirm),
    );
  }
}
