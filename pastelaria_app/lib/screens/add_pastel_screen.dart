import 'package:flutter/material.dart';
import '../ui/app_ui.dart';
import '../models/pricing_rules.dart';
import '../models/pastel_extra.dart';

enum PastelType { none, pizza, misto }

class AddPastelScreen extends StatefulWidget {
  final PricingRules pricing;
  const AddPastelScreen({super.key, this.pricing = const PricingRules()});
  @override
  State<AddPastelScreen> createState() => _AddPastelScreenState();
}

class _AddPastelScreenState extends State<AddPastelScreen> {
  static const _ingredients = [
    'Carne',
    'Frango',
    'Presunto',
    'Bacon',
    'Queijo',
    'Catupiry',
    'Gueroba',
    'Milho',
    'Calabresa',
    'Tomate',
    'Cebola',
    'Cebolinha',
    'Azeitona',
    'Orégano'
  ];
  final Set<String> _selected = {};
  final List<PastelExtra> _extras = [];
  final _notes = TextEditingController();
  int _quantity = 1;
  PastelType _type = PastelType.none;
  Future<void> _addExtra() async {
    final extra = await showDialog<PastelExtra>(
        context: context,
        builder: (_) => _ExtraDialog(defaultCents: widget.pricing.extra));
    if (extra != null && mounted) setState(() => _extras.add(extra));
  }

  List<String> get _filling => _type == PastelType.pizza
      ? ['Pizza']
      : _type == PastelType.misto
          ? ['Misto']
          : _ingredients.where(_selected.contains).toList();
  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Widget _ingredientButtons(double width) {
    final columns = (width / 175).floor().clamp(2, 5);
    final cellWidth = (width - (columns - 1) * 10) / columns;
    return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: _ingredients.map((ingredient) {
          final selected = _selected.contains(ingredient);
          final free = ['Cebola', 'Cebolinha', 'Orégano'].contains(ingredient);
          return SizedBox(
              width: cellWidth,
              child: Semantics(
                  selected: selected,
                  button: true,
                  child: Material(
                    color: selected ? ink : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => setState(() {
                              selected
                                  ? _selected.remove(ingredient)
                                  : _selected.add(ingredient);
                            }),
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 80),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                              border: Border.all(
                                  color:
                                      selected ? ink : const Color(0xFFCCD4CD)),
                              borderRadius: BorderRadius.circular(12)),
                          child: Row(children: [
                            Expanded(
                                child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text(ingredient,
                                      style: TextStyle(
                                          color: selected ? Colors.white : ink,
                                          fontSize: 17,
                                          fontWeight: FontWeight.w700)),
                                  if (free)
                                    Text('Gratuito',
                                        style: TextStyle(
                                            color: selected
                                                ? Colors.white70
                                                : success,
                                            fontSize: 12)),
                                ])),
                            Icon(
                                selected
                                    ? Icons.check_circle
                                    : Icons.add_circle_outline,
                                color: selected ? Colors.white : mutedInk,
                                size: 21)
                          ]),
                        )),
                  )));
        }).toList());
  }

  @override
  Widget build(BuildContext context) {
    final filling = _filling;
    final unit = pastelUnitCents(filling, rules: widget.pricing) +
        extraUnitCents(_extras);
    return Scaffold(
      appBar: AppBar(title: const Text('Escolher recheios')),
      body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Center(
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SurfaceCard(
                            child: Wrap(
                                alignment: WrapAlignment.spaceBetween,
                                runSpacing: 12,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                              const Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Monte do seu jeito',
                                        style: TextStyle(
                                            fontSize: 26,
                                            fontWeight: FontWeight.w800)),
                                    SizedBox(height: 4),
                                    Text('Escolha os recheios e a quantidade.',
                                        style: TextStyle(
                                            color: mutedInk, fontSize: 17))
                                  ]),
                              QuantityStepper(
                                  value: _quantity,
                                  onChanged: (v) =>
                                      setState(() => _quantity = v))
                            ])),
                        const SizedBox(height: 20),
                        SegmentedButton<PastelType>(
                            showSelectedIcon: false,
                            segments: [
                              const ButtonSegment(
                                  value: PastelType.none,
                                  label: Text('Personalizado')),
                              ButtonSegment(
                                  value: PastelType.pizza,
                                  label: Text(
                                      'Pizza · ${money(widget.pricing.pizza)}')),
                              ButtonSegment(
                                  value: PastelType.misto,
                                  label: Text(
                                      'Misto · ${money(widget.pricing.misto)}'))
                            ],
                            selected: {_type},
                            onSelectionChanged: (s) =>
                                setState(() => _type = s.single)),
                        const SizedBox(height: 20),
                        if (_type == PastelType.none) ...[
                          const Text('Toque para selecionar os ingredientes',
                              style: TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 6),
                          Text(
                              'Até 2 recheios pagos: ${money(widget.pricing.base)}. Cada adicional: ${money(widget.pricing.extra)}. Temperos indicados são gratuitos.',
                              style: const TextStyle(
                                  color: mutedInk, fontSize: 16)),
                          const SizedBox(height: 14),
                          LayoutBuilder(
                              builder: (context, c) =>
                                  _ingredientButtons(c.maxWidth)),
                        ] else
                          SurfaceCard(
                              child: Row(children: [
                            const Icon(Icons.restaurant,
                                color: brand, size: 36),
                            const SizedBox(width: 16),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text(
                                      _type == PastelType.pizza
                                          ? 'Pastel de Pizza'
                                          : 'Pastel Misto',
                                      style: const TextStyle(
                                          fontSize: 23,
                                          fontWeight: FontWeight.w800)),
                                  const SizedBox(height: 4),
                                  Text(
                                      _type == PastelType.pizza
                                          ? 'Presunto, queijo, tomate e orégano.'
                                          : 'Pastel especial com os recheios da casa.',
                                      style: const TextStyle(
                                          fontSize: 17, color: mutedInk))
                                ]))
                          ])),
                        const SizedBox(height: 20),
                        SurfaceCard(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              const Text('Resumo do recheio',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(height: 8),
                              Text(
                                  filling.isEmpty
                                      ? 'Selecione ao menos um ingrediente para continuar.'
                                      : filling.join(' · '),
                                  style: const TextStyle(
                                      fontSize: 18, color: mutedInk)),
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                  onPressed: _addExtra,
                                  icon: const Icon(Icons.add_circle_outline),
                                  label: const Text('Recheio adicional')),
                              for (final extra in _extras)
                                Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Row(children: [
                                      Expanded(
                                          child: Text(
                                              'Adicional: ${extra.description}',
                                              style: const TextStyle(
                                                  fontSize: 18, color: brand))),
                                      IconButton(
                                          tooltip:
                                              'Remover adicional ${extra.name}',
                                          onPressed: () => setState(
                                              () => _extras.remove(extra)),
                                          icon: const Icon(Icons.close)),
                                    ])),
                              const SizedBox(height: 16),
                              TextField(
                                  controller: _notes,
                                  minLines: 1,
                                  maxLines: 3,
                                  decoration: const InputDecoration(
                                      labelText: 'Observação destes pastéis',
                                      hintText:
                                          'Ex.: sem cebola, bem passado')),
                            ])),
                      ])))),
      bottomNavigationBar: SafeArea(
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
                      Text('${money(unit)} por pastel',
                          style: const TextStyle(color: mutedInk)),
                      Text(money(unit * _quantity),
                          style: const TextStyle(
                              fontSize: 28, fontWeight: FontWeight.w800))
                    ])),
                FilledButton.icon(
                    onPressed: filling.isEmpty
                        ? null
                        : () => Navigator.pop(context, {
                              'quantidade': _quantity,
                              'ingredientes': filling,
                              'adicionais': _extras
                                  .map((extra) => extra.toJson())
                                  .toList(),
                              'observacoesItem': _notes.text.trim()
                            }),
                    icon: const Icon(Icons.add),
                    label: Text(
                        'Adicionar $_quantity ${_quantity == 1 ? 'pastel' : 'pastéis'}'))
              ]))),
    );
  }
}

class _ExtraDialog extends StatefulWidget {
  final int defaultCents;
  const _ExtraDialog({required this.defaultCents});
  @override
  State<_ExtraDialog> createState() => _ExtraDialogState();
}

class _ExtraDialogState extends State<_ExtraDialog> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  late final _price = TextEditingController(
      text:
          '${widget.defaultCents ~/ 100},${(widget.defaultCents % 100).toString().padLeft(2, '0')}');
  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Recheio adicional'),
        content: SingleChildScrollView(
            child: SizedBox(
                width: 420,
                child: Form(
                    key: _form,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      TextFormField(
                          key: const ValueKey('extra-name'),
                          controller: _name,
                          autofocus: true,
                          maxLength: 80,
                          decoration: const InputDecoration(
                              labelText: 'Nome do adicional',
                              errorMaxLines: 3,
                              hintText: 'Ex.: camarão, queijo extra'),
                          validator: (value) {
                            try {
                              PastelExtra.fromJson(
                                  {'nome': value, 'preco_centavos': 0});
                              return null;
                            } on FormatException catch (error) {
                              return error.message;
                            }
                          }),
                      const SizedBox(height: 16),
                      TextFormField(
                          key: const ValueKey('extra-price'),
                          controller: _price,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration(
                              labelText: 'Valor por pastel (R\$)',
                              helperMaxLines: 3,
                              errorMaxLines: 3,
                              helperText:
                                  'Valor sugerido pelo cadastro. Pode ajustar para este item.'),
                          validator: (value) => PricingRules.parsePrice(
                                      value ?? '') ==
                                  null
                              ? 'Informe de 0,00 a 9.999,99, com até duas casas decimais.'
                              : null),
                      const SizedBox(height: 12),
                      const Text(
                          'O valor será cobrado em cada pastel deste item.',
                          style: TextStyle(color: mutedInk)),
                    ])))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () {
                if (_form.currentState!.validate()) {
                  Navigator.pop(
                      context,
                      PastelExtra.fromJson({
                        'nome': _name.text,
                        'preco_centavos': PricingRules.parsePrice(_price.text)!
                      }));
                }
              },
              child: const Text('Adicionar recheio')),
        ],
      );
}
