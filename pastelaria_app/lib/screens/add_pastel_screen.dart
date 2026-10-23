import 'package:flutter/material.dart';
import '../ui/app_ui.dart';

enum PastelType { none, pizza, misto }

class AddPastelScreen extends StatefulWidget {
  const AddPastelScreen({super.key});
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
  final _notes = TextEditingController();
  int _quantity = 1;
  PastelType _type = PastelType.none;
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
    final unit = pastelUnitCents(filling);
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
                            segments: const [
                              ButtonSegment(
                                  value: PastelType.none,
                                  label: Text('Personalizado')),
                              ButtonSegment(
                                  value: PastelType.pizza,
                                  label: Text('Pizza · R\$ 15')),
                              ButtonSegment(
                                  value: PastelType.misto,
                                  label: Text('Misto · R\$ 25'))
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
                          const Text(
                              'Até 2 recheios pagos: R\$ 12. Cada adicional: R\$ 3. Temperos indicados são gratuitos.',
                              style: TextStyle(color: mutedInk, fontSize: 16)),
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
                              'observacoesItem': _notes.text.trim()
                            }),
                    icon: const Icon(Icons.add),
                    label: Text(
                        'Adicionar $_quantity ${_quantity == 1 ? 'pastel' : 'pastéis'}'))
              ]))),
    );
  }
}
