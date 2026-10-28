import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/item_pedido.dart';
import '../models/beverage_catalog.dart';
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
  BeverageCategory? _category;
  bool _selectedOnly = false;
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

  String _normalize(String s) => BeverageCatalog.normalize(s);

  int _cents(dynamic p) =>
      p['preco_centavos'] as int? ?? ((p['preco'] as num) * 100).round();

  bool get _drinks => widget.productType == 'bebida';
  IconData _categoryIcon(BeverageCategory category) => switch (category) {
        BeverageCategory.beer => Icons.sports_bar_outlined,
        BeverageCategory.water => Icons.water_drop_outlined,
        BeverageCategory.juice => Icons.local_bar_outlined,
        BeverageCategory.energy => Icons.bolt,
        BeverageCategory.cans => Icons.local_drink_outlined,
        _ => Icons.liquor_outlined,
      };
  void _choose(BeverageCategory? category) {
    _searchController.clear();
    setState(() {
      _category = category;
      _search = '';
      _selectedOnly = false;
    });
  }

  Widget _photo(String name) {
    final asset = BeverageCatalog.image(name);
    final category = BeverageCatalog.category(name);
    final fallback = Icon(_categoryIcon(category), size: 52, color: mutedInk);
    return SizedBox(
        height: 82,
        width: double.infinity,
        child: asset == null
            ? Center(child: fallback)
            : Image.asset(asset,
                fit: BoxFit.contain,
                cacheWidth: 180,
                excludeFromSemantics: true,
                frameBuilder: (context, child, frame, synchronous) =>
                    frame == null ? Center(child: fallback) : child,
                errorBuilder: (_, error, stack) => Center(child: fallback)));
  }

  Widget _categories(List<dynamic> products) {
    final available = BeverageCategory.values
        .where((c) => products
            .any((p) => BeverageCatalog.category(p['nome'] as String) == c))
        .toList();
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth - 40;
      final columns = width >= 700
          ? 4
          : width >= 460
              ? 3
              : 2;
      return GridView.builder(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisExtent:
                  168 + (MediaQuery.textScalerOf(context).scale(18) - 18) * 5,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12),
          itemCount: available.length,
          itemBuilder: (context, index) {
            final category = available[index];
            final items = products
                .where((p) =>
                    BeverageCatalog.category(p['nome'] as String) == category)
                .toList();
            final selected = items.fold<int>(
                0, (sum, p) => sum + (_quantities[p['id']] ?? 0));
            return Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                    key: ValueKey('category-${category.name}'),
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => _choose(category),
                    child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: selected > 0
                                    ? success
                                    : const Color(0xFFE0E5DF),
                                width: selected > 0 ? 2 : 1)),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(_categoryIcon(category),
                                  size: 30, color: brand),
                              const SizedBox(height: 10),
                              Expanded(
                                  child: Text(category.label,
                                      style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800))),
                              Text(
                                  '${items.length} ${items.length == 1 ? 'produto' : 'produtos'}${selected > 0 ? ' · $selected na seleção' : ''}',
                                  style: TextStyle(
                                      color: selected > 0 ? success : mutedInk,
                                      fontSize: 13)),
                            ]))));
          });
    });
  }

  Widget _footer(List<dynamic> products, int units, int total) {
    final summary = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$units unidades selecionadas',
              style: const TextStyle(color: mutedInk)),
          Text(money(total),
              style:
                  const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
        ]);
    final add = FilledButton.icon(
        onPressed: units == 0
            ? null
            : () {
                final selected = products
                    .where((p) => (_quantities[p['id']] ?? 0) > 0)
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
        label: const Text('Adicionar ao pedido'));
    return SafeArea(
        top: false,
        child: Container(
            color: Colors.white,
            padding: const EdgeInsets.all(18),
            child: LayoutBuilder(
                builder: (context, c) => c.maxWidth >= 600
                    ? Row(children: [
                        Expanded(child: summary),
                        const SizedBox(width: 16),
                        add
                      ])
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                            summary,
                            const SizedBox(height: 10),
                            add
                          ]))));
  }

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
              final categories = BeverageCategory.values
                  .where((c) => products.any((p) =>
                      BeverageCatalog.category(p['nome'] as String) == c))
                  .toList();
              final overview = _drinks &&
                  products.isNotEmpty &&
                  _category == null &&
                  _search.trim().isEmpty &&
                  !_selectedOnly;
              final visible = products
                  .where((p) =>
                      _normalize(p['nome'] as String)
                          .contains(_normalize(_search)) &&
                      (!_drinks ||
                          _category == null ||
                          BeverageCatalog.category(p['nome'] as String) ==
                              _category) &&
                      (!_selectedOnly || (_quantities[p['id']] ?? 0) > 0))
                  .toList();
              final units = _quantities.values.fold<int>(0, (a, b) => a + b);
              final total = products.fold<int>(
                  0, (n, p) => n + _cents(p) * (_quantities[p['id']] ?? 0));
              return Column(children: [
                Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: TextField(
                        controller: _searchController,
                        onChanged: (v) => setState(() {
                              _search = v;
                              if (_drinks && v.trim().isNotEmpty) {
                                _category = null;
                                _selectedOnly = false;
                              }
                            }),
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
                if (_drinks) ...[
                  SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                      child: Row(children: [
                        ActionChip(
                            avatar: const Icon(Icons.grid_view, size: 18),
                            label: const Text('Categorias'),
                            onPressed: () => _choose(null)),
                        const SizedBox(width: 8),
                        if (units > 0)
                          ChoiceChip(
                              label: Text('Ver selecionados ($units)'),
                              selected: _selectedOnly,
                              onSelected: (value) => setState(() {
                                    _selectedOnly = value;
                                    _category = null;
                                    _search = '';
                                    _searchController.clear();
                                  })),
                        if (!overview) ...[
                          const SizedBox(width: 8),
                          ...categories.map((category) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                  label: Text(category.label),
                                  selected: _category == category,
                                  onSelected: (_) => _choose(category)))),
                        ],
                      ])),
                  if (overview)
                    const Padding(
                        padding: EdgeInsets.fromLTRB(20, 0, 20, 14),
                        child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                                'Escolha uma categoria ou busque em todas as bebidas.',
                                style: TextStyle(color: mutedInk)))),
                  if (_search.trim().isNotEmpty)
                    const Padding(
                        padding: EdgeInsets.fromLTRB(20, 0, 20, 10),
                        child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text('Busca em todas as bebidas',
                                style: TextStyle(color: mutedInk)))),
                ],
                Expanded(
                    child: overview
                        ? _categories(products)
                        : visible.isEmpty
                            ? const Center(
                                child: Text('Nenhum produto encontrado.',
                                    style: TextStyle(fontSize: 20)))
                            : LayoutBuilder(
                                builder: (context, constraints) =>
                                    GridView.builder(
                                        padding: const EdgeInsets.fromLTRB(
                                            20, 0, 20, 20),
                                        gridDelegate:
                                            SliverGridDelegateWithFixedCrossAxisCount(
                                                crossAxisCount: ((constraints
                                                                .maxWidth -
                                                            40) /
                                                        (_drinks ? 220 : 300))
                                                    .floor()
                                                    .clamp(1, 5),
                                                mainAxisExtent: (_drinks
                                                        ? 268
                                                        : 180) +
                                                    (MediaQuery.textScalerOf(
                                                                    context)
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
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                  color: quantity > 0
                                                      ? const Color(0xFFEDF5F0)
                                                      : Colors.white,
                                                  border: Border.all(
                                                      color: quantity > 0
                                                          ? success
                                                          : const Color(
                                                              0xFFE0E5DF),
                                                      width:
                                                          quantity > 0 ? 2 : 1),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          16)),
                                              child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    if (_drinks) ...[
                                                      _photo(
                                                          p['nome'] as String),
                                                      const SizedBox(height: 10)
                                                    ],
                                                    Expanded(
                                                        child: Text(
                                                            p['nome'] as String,
                                                            maxLines: 2,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            style: const TextStyle(
                                                                fontSize: 20,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w800))),
                                                    Text(money(_cents(p)),
                                                        style: const TextStyle(
                                                            fontSize: 18,
                                                            color: mutedInk)),
                                                    const SizedBox(height: 8),
                                                    Align(
                                                        alignment: Alignment
                                                            .centerRight,
                                                        child: QuantityStepper(
                                                            value: quantity,
                                                            min: 0,
                                                            label: p['nome']
                                                                as String,
                                                            onChanged: (v) =>
                                                                setState(() =>
                                                                    _quantities[
                                                                            id] =
                                                                        v))),
                                                  ]));
                                        }))),
                _footer(products, units, total),
              ]);
            }),
      );
}
