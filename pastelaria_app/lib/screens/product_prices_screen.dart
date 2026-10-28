import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/pricing_rules.dart';
import '../services/api_service.dart';
import '../services/app_settings.dart';
import '../ui/app_ui.dart';

class ProductPricesScreen extends StatefulWidget {
  final ApiService? api;
  const ProductPricesScreen({super.key, this.api});
  @override
  State<ProductPricesScreen> createState() => _ProductPricesScreenState();
}

class _ProductPricesScreenState extends State<ProductPricesScreen> {
  final _form = GlobalKey<FormState>();
  final _fields = <String, TextEditingController>{};
  final _original = <String, int>{};
  final _labels = <String, String>{};
  Map<String, dynamic>? _catalog;
  String _search = '', _type = 'todos';
  String? _error, _commandId, _fingerprint;
  bool _loading = true, _saving = false;
  static const ruleLabels = {
    'base_centavos': 'Pastel personalizado (até 2 recheios pagos)',
    'adicional_centavos': 'Cada recheio pago além dos 2 incluídos',
    'pizza_centavos': 'Pastel de Pizza',
    'misto_centavos': 'Pastel Misto'
  };
  bool get _dirty => _fields.entries
      .any((e) => PricingRules.parsePrice(e.value.text) != _original[e.key]);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final field in _fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await (widget.api ?? ApiService()).getPriceCatalog();
      if (mounted) _adopt(data);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _adopt(Map<String, dynamic> data) {
    _original.clear();
    _labels.clear();
    void add(String key, String label, int cents) {
      final controller =
          _fields.putIfAbsent(key, () => TextEditingController());
      controller.text =
          '${cents ~/ 100},${(cents % 100).toString().padLeft(2, '0')}';
      _original[key] = cents;
      _labels[key] = label;
    }

    for (final entry in ruleLabels.entries) {
      add('r:${entry.key}', entry.value, data['rules'][entry.key] as int);
    }
    for (final product in data['products'] as List) {
      if (['bebida', 'salgado'].contains(product['tipo'])) {
        add('p:${product['id']}', product['nome'] as String,
            product['preco_centavos'] as int);
      }
    }
    setState(() {
      _catalog = data;
      _error = null;
    });
  }

  Future<void> _reload() async {
    if (_dirty) {
      final discard = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
                  title: const Text('Descartar as edições?'),
                  content: const Text(
                      'Os valores ainda não salvos serão substituídos pela tabela do servidor.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(c, false),
                        child: const Text('Manter edição')),
                    FilledButton(
                        onPressed: () => Navigator.pop(c, true),
                        child: const Text('Recarregar'))
                  ]));
      if (discard != true || !mounted) return;
    }
    await _load();
  }

  Future<void> _save() async {
    for (final entry in _fields.entries) {
      if (PricingRules.parsePrice(entry.value.text) == null) {
        _form.currentState?.validate();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Confira o valor de ${_labels[entry.key]}.')));
        return;
      }
    }
    if (_saving || !_dirty || !_form.currentState!.validate()) return;
    final changed = _fields.entries
        .where((e) => PricingRules.parsePrice(e.value.text) != _original[e.key])
        .toList();
    final confirm = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
                title: const Text('Salvar novos preços?'),
                content: SizedBox(
                    width: 500,
                    child: SingleChildScrollView(
                        child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          const Text(
                              'Valem para os próximos pedidos. Pedidos já confirmados mantêm os valores originais.'),
                          const SizedBox(height: 16),
                          for (final entry in changed)
                            Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Text(
                                    '${_labels[entry.key]}\n${money(_original[entry.key]!)} → ${money(PricingRules.parsePrice(entry.value.text)!)}')),
                        ]))),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('Voltar')),
                  FilledButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('Salvar preços'))
                ]));
    if (confirm != true || !mounted) return;
    final payload = <String, dynamic>{
      'expected_catalog_revision': _catalog!['catalog_revision'],
      'rules': {
        for (final key in ruleLabels.keys)
          key: PricingRules.parsePrice(_fields['r:$key']!.text)
      },
      'products': [
        for (final entry in changed.where((e) => e.key.startsWith('p:')))
          {
            'id': int.parse(entry.key.substring(2)),
            'preco_centavos': PricingRules.parsePrice(entry.value.text)
          }
      ]
    };
    final fingerprint = jsonEncode(payload);
    if (_fingerprint != fingerprint) {
      _fingerprint = fingerprint;
      _commandId = newCommandId();
    }
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      final result = await (widget.api ?? ApiService())
          .command('update_prices', payload, commandId: _commandId);
      if (!mounted) return;
      _adopt(result);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Preços salvos no servidor.')));
    } catch (error) {
      if (mounted) {
        setState(() => _error = '$error');
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field(String key) => Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
          key: ValueKey(key),
          controller: _fields[key],
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
              labelText: _labels[key], prefixText: 'R\$ ', hintText: '12,50'),
          onChanged: (_) => setState(() {}),
          validator: (text) => PricingRules.parsePrice(text ?? '') == null
              ? 'Use um valor de 0,00 a 9999,99, com até 2 casas decimais.'
              : null));

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(title: const Text('Preços dos produtos'), actions: [
          IconButton(
              tooltip: 'Recarregar preços',
              onPressed: _loading || _saving ? null : _reload,
              icon: const Icon(Icons.refresh)),
        ]),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : AbsorbPointer(
                absorbing: _saving,
                child: Form(
                    key: _form,
                    child: Center(
                        child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 850),
                            child: ListView(
                                padding: const EdgeInsets.all(20),
                                children: [
                                  if (_error != null)
                                    Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 16),
                                        child: Text(_error!,
                                            style:
                                                const TextStyle(color: brand))),
                                  if (_catalog == null)
                                    FilledButton(
                                        onPressed: _load,
                                        child: const Text('Tentar novamente')),
                                  if (_catalog != null) ...[
                                    const Text(
                                        'Altere os valores e salve ao terminar. O histórico mantém os preços das vendas.',
                                        style: TextStyle(color: mutedInk)),
                                    const SizedBox(height: 18),
                                    TextField(
                                        decoration: const InputDecoration(
                                            labelText: 'Buscar produto',
                                            prefixIcon: Icon(Icons.search)),
                                        onChanged: (value) => setState(() =>
                                            _search =
                                                value.toLowerCase().trim())),
                                    const SizedBox(height: 12),
                                    Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: const {
                                          'todos': 'Todos',
                                          'pastel': 'Pastéis',
                                          'bebida': 'Bebidas',
                                          'salgado': 'Salgados'
                                        }
                                            .entries
                                            .map((e) => ChoiceChip(
                                                label: Text(e.value),
                                                selected: _type == e.key,
                                                onSelected: (_) => setState(
                                                    () => _type = e.key)))
                                            .toList()),
                                    const SizedBox(height: 20),
                                    if (_type == 'todos' ||
                                        _type == 'pastel') ...[
                                      const Text('Pastéis e adicionais',
                                          style: TextStyle(
                                              fontSize: 23,
                                              fontWeight: FontWeight.w800)),
                                      const SizedBox(height: 14),
                                      for (final key in ruleLabels.keys)
                                        if (_labels['r:$key']!
                                            .toLowerCase()
                                            .contains(_search))
                                          _field('r:$key'),
                                      const Text(
                                          'Cebola, cebolinha e orégano continuam gratuitos. Os outros recheios seguem o limite de 2 incluídos e o preço adicional acima.',
                                          style: TextStyle(color: mutedInk)),
                                      const SizedBox(height: 22),
                                    ],
                                    for (final product
                                        in _catalog!['products'] as List)
                                      if (['bebida', 'salgado']
                                              .contains(product['tipo']) &&
                                          (_type == 'todos' ||
                                              _type == product['tipo']) &&
                                          (product['nome'] as String)
                                              .toLowerCase()
                                              .contains(_search))
                                        _field('p:${product['id']}'),
                                  ],
                                ]))))),
        bottomNavigationBar: SafeArea(
            child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton.icon(
                    onPressed:
                        !_loading && !_saving && _catalog != null && _dirty
                            ? _save
                            : null,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(_saving ? 'Salvando…' : 'Salvar alterações')))),
      ));
}
