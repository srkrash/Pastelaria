import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/item_pedido.dart';
import '../ui/app_ui.dart';

class AddProductScreen extends StatefulWidget {
  final String productType;
  final ApiService? api;
  const AddProductScreen({super.key, required this.productType, this.api});
  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  late Future<List<dynamic>> _products;
  final Map<int, int> _quantities = {};
  String _search = '';
  final _searchController = TextEditingController();
  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _products =
        (widget.api ?? ApiService()).getProdutos(tipo: widget.productType);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _normalize(String s) {
    const from = 'áàâãäéèêëíìîïóòôõöúùûüç';
    const to = 'aaaaaeeeeiiiiooooouuuuc';
    return s.toLowerCase().split('').map((c) {
      final i = from.indexOf(c);
      return i < 0 ? c : to[i];
    }).join();
  }

  int _cents(dynamic p) =>
      p['preco_centavos'] as int? ?? ((p['preco'] as num) * 100).round();
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title:
                Text(widget.productType == 'bebida' ? 'Bebidas' : 'Salgados')),
        body: FutureBuilder<List<dynamic>>(
            future: _products,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                    child: Padding(
                        padding: const EdgeInsets.all(24),
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.wifi_off, size: 42, color: mutedInk),
                          const SizedBox(height: 16),
                          const Text('Não foi possível carregar os produtos.',
                              style: TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          Text('${snapshot.error}',
                              textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                              onPressed: () => setState(_reload),
                              icon: const Icon(Icons.refresh),
                              label: const Text('Tentar novamente'))
                        ])));
              }
              final products = snapshot.data ?? [];
              final visible = products
                  .where((p) => _normalize(p['nome'] as String)
                      .contains(_normalize(_search)))
                  .toList();
              final units = _quantities.values.fold<int>(0, (a, b) => a + b);
              final total = products.fold<int>(
                  0, (n, p) => n + _cents(p) * (_quantities[p['id']] ?? 0));
              return Column(children: [
                Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: TextField(
                        controller: _searchController,
                        onChanged: (v) => setState(() => _search = v),
                        decoration: InputDecoration(
                            hintText: 'Buscar pelo nome',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _search.isEmpty
                                ? null
                                : IconButton(
                                    tooltip: 'Limpar busca',
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _search = '');
                                    },
                                    icon: const Icon(Icons.close))))),
                Expanded(
                    child: visible.isEmpty
                        ? const Center(
                            child: Text('Nenhum produto encontrado.',
                                style: TextStyle(fontSize: 20)))
                        : GridView.builder(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                            gridDelegate:
                                SliverGridDelegateWithMaxCrossAxisExtent(
                                    maxCrossAxisExtent: 360,
                                    mainAxisExtent: 180 +
                                        (MediaQuery.textScalerOf(context)
                                                    .scale(20) -
                                                20) *
                                            4,
                                    mainAxisSpacing: 14,
                                    crossAxisSpacing: 14),
                            itemCount: visible.length,
                            itemBuilder: (context, index) {
                              final p = visible[index];
                              final id = p['id'] as int;
                              final quantity = _quantities[id] ?? 0;
                              return Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                      color: quantity > 0
                                          ? const Color(0xFFEDF5F0)
                                          : Colors.white,
                                      border: Border.all(
                                          color: quantity > 0
                                              ? success
                                              : const Color(0xFFE0E5DF),
                                          width: quantity > 0 ? 2 : 1),
                                      borderRadius: BorderRadius.circular(16)),
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                            child: Text(p['nome'] as String,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                    fontSize: 20,
                                                    fontWeight:
                                                        FontWeight.w800))),
                                        Text(money(_cents(p)),
                                            style: const TextStyle(
                                                fontSize: 18, color: mutedInk)),
                                        const SizedBox(height: 8),
                                        Align(
                                            alignment: Alignment.centerRight,
                                            child: QuantityStepper(
                                                value: quantity,
                                                min: 0,
                                                label: p['nome'] as String,
                                                onChanged: (v) => setState(() =>
                                                    _quantities[id] = v))),
                                      ]));
                            })),
                SafeArea(
                    top: false,
                    child: Container(
                        color: Colors.white,
                        padding: const EdgeInsets.all(18),
                        child: Row(children: [
                          Expanded(
                              child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text('$units unidades selecionadas',
                                    style: const TextStyle(color: mutedInk)),
                                Text(money(total),
                                    style: const TextStyle(
                                        fontSize: 26,
                                        fontWeight: FontWeight.w800))
                              ])),
                          FilledButton.icon(
                              onPressed: units == 0
                                  ? null
                                  : () {
                                      final selected = products
                                          .where((p) =>
                                              (_quantities[p['id']] ?? 0) > 0)
                                          .map((p) => ItemPedido(
                                              id: p['id'] as int,
                                              pedidoId: 0,
                                              numeroPedido: 0,
                                              quantidade: _quantities[p['id']]!,
                                              produtoNome: p['nome'] as String,
                                              statusItem: 'pronto',
                                              preco: _cents(p) / 100,
                                              ingredientes: [],
                                              observacoesItem: ''))
                                          .toList();
                                      Navigator.pop(context, selected);
                                    },
                              icon: const Icon(Icons.add),
                              label: const Text('Adicionar ao pedido'))
                        ]))),
              ]);
            }),
      );
}
