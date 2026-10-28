import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import '../services/api_service.dart';
import '../ui/app_ui.dart';

class BiScreen extends StatefulWidget {
  final ApiService? api;
  final DateTime? today;
  const BiScreen({super.key, this.api, this.today});
  @override
  State<BiScreen> createState() => _BiScreenState();
}

class _BiScreenState extends State<BiScreen> {
  late DateTime _today, _from, _to;
  late Future<Map<String, dynamic>> _report;
  String _preset = 'Hoje', _group = 'daily', _metric = 'value_centavos';
  static const _presets = ['Hoje', 'Ontem', '7 dias', '30 dias', 'Este mês'];
  static const _groups = {
    'hourly': 'Hora',
    'daily': 'Dia',
    'weekly': 'Semana',
    'monthly': 'Mês',
    'weekdays': 'Dia da semana',
  };
  static const _metrics = {
    'value_centavos': 'Valor',
    'orders': 'Pedidos',
    'quantity': 'Unidades'
  };
  String _iso(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
  String _date(DateTime d) => DateFormat('dd/MM/yyyy').format(d);
  @override
  void initState() {
    super.initState();
    final now =
        widget.today ?? tz.TZDateTime.now(tz.getLocation('America/Sao_Paulo'));
    _today = DateTime(now.year, now.month, now.day);
    _from = _to = _today;
    _load();
  }

  void _load() {
    _report = (widget.api ?? ApiService()).getBi(_iso(_from), _iso(_to));
  }

  void _select(String preset) => setState(() {
        _preset = preset;
        _to = preset == 'Ontem'
            ? _today.subtract(const Duration(days: 1))
            : _today;
        _from = preset == '7 dias'
            ? _to.subtract(const Duration(days: 6))
            : preset == '30 dias'
                ? _to.subtract(const Duration(days: 29))
                : preset == 'Este mês'
                    ? DateTime(_today.year, _today.month)
                    : _to;
        _load();
      });

  Future<void> _custom() async {
    final range = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: _today,
        initialDateRange: DateTimeRange(start: _from, end: _to),
        helpText: 'Período do BI (até 366 dias)',
        saveText: 'Aplicar',
        cancelText: 'Cancelar');
    if (range == null || !mounted) return;
    // Calendar dates: use UTC for duration so daylight saving cannot alter days.
    final days = DateTime.utc(range.end.year, range.end.month, range.end.day)
            .difference(DateTime.utc(
                range.start.year, range.start.month, range.start.day))
            .inDays +
        1;
    if (days > 366) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Escolha no máximo 366 dias.')));
      return;
    }
    setState(() {
      _from = range.start;
      _to = range.end;
      _preset = 'Personalizado';
      _load();
    });
  }

  String _change(int current, int previous) {
    if (previous == 0) {
      return current == 0
          ? 'Sem movimento nos dois períodos'
          : 'Sem base no período anterior';
    }
    final delta = (current - previous) * 100 / previous;
    return '${delta > 0 ? '+' : ''}${delta.toStringAsFixed(1).replaceAll('.', ',')}% em relação ao anterior';
  }

  Widget _heading(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Text(text,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)));

  Widget _kpis(Map current, Map previous) {
    final entries = [
      (
        'Valor dos pedidos',
        money(current['value_centavos'] as int),
        'value_centavos'
      ),
      ('Pedidos válidos', '${current['orders']}', 'orders'),
      (
        'Ticket médio',
        money(current['ticket_centavos'] as int),
        'ticket_centavos'
      ),
      ('Unidades vendidas', '${current['quantity']}', 'quantity'),
    ];
    return LayoutBuilder(builder: (context, constraints) {
      final columns = constraints.maxWidth >= 1050
          ? 4
          : constraints.maxWidth >= 620
              ? 2
              : 1;
      final width = (constraints.maxWidth - (columns - 1) * 14) / columns;
      return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: entries
              .map((e) => SizedBox(
                  width: width,
                  child: SurfaceCard(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(e.$1,
                            style: const TextStyle(
                                color: mutedInk, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 12),
                        Text(e.$2,
                            style: const TextStyle(
                                fontSize: 28, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 10),
                        Text(
                            _change(
                                current[e.$3] as int, previous[e.$3] as int),
                            style:
                                const TextStyle(color: mutedInk, fontSize: 13)),
                      ]))))
              .toList());
    });
  }

  String _label(String label) {
    if (_group == 'daily' || _group == 'weekly') {
      final d = DateTime.parse(label);
      return DateFormat('dd/MM').format(d);
    }
    if (_group == 'monthly') {
      return '${label.substring(5)}/${label.substring(0, 4)}';
    }
    return label;
  }

  Widget _chart(Map current) {
    final rows = current[_group] as List;
    final maximum =
        rows.fold<int>(1, (value, row) => math.max(value, row[_metric] as int));
    return SurfaceCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _heading('Movimento no período'),
      Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _groups.entries
              .map((e) => ChoiceChip(
                  label: Text(e.value),
                  selected: _group == e.key,
                  onSelected: (_) => setState(() => _group = e.key)))
              .toList()),
      const SizedBox(height: 10),
      Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _metrics.entries
              .map((e) => ChoiceChip(
                  label: Text(e.value),
                  selected: _metric == e.key,
                  onSelected: (_) => setState(() => _metric = e.key)))
              .toList()),
      const SizedBox(height: 20),
      if (current['orders'] == 0)
        const Padding(
            padding: EdgeInsets.only(bottom: 14),
            child: Text('Nenhum pedido válido neste período.')),
      LayoutBuilder(builder: (context, constraints) {
        final width = math.max(constraints.maxWidth, rows.length * 42.0);
        final every = math.max(1, (rows.length / 14).ceil());
        return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
                width: width,
                height: 222,
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(rows.length, (index) {
                      final row = rows[index] as Map;
                      final value = row[_metric] as int;
                      final caption =
                          _metric == 'value_centavos' ? money(value) : '$value';
                      final label = _label(row['label'] as String);
                      return Expanded(
                          child: Tooltip(
                              message: '$label · $caption',
                              triggerMode: TooltipTriggerMode.tap,
                              child: Semantics(
                                  label: '$label: $caption',
                                  child: Column(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        Container(
                                            margin: const EdgeInsets.symmetric(
                                                horizontal: 5),
                                            height: value == 0
                                                ? 2
                                                : 160 * value / maximum,
                                            decoration: BoxDecoration(
                                                color: value == 0
                                                    ? const Color(0xFFE0E5DF)
                                                    : success,
                                                borderRadius:
                                                    BorderRadius.circular(5))),
                                        const SizedBox(height: 8),
                                        SizedBox(
                                            height: 46,
                                            child: index % every == 0
                                                ? Text(label,
                                                    textAlign: TextAlign.center,
                                                    style: const TextStyle(
                                                        fontSize: 11))
                                                : const SizedBox.shrink()),
                                      ]))));
                    }))));
      }),
      const Text(
          'Toque nas barras para ver os valores. Deslize para ver todo o período.',
          style: TextStyle(color: mutedInk, fontSize: 13)),
      if (_group == 'hourly')
        const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
                'Horas de São Paulo; soma de todos os dias selecionados.',
                style: TextStyle(color: mutedInk))),
      if (_group == 'weekly')
        const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
                'Semanas começam na segunda-feira. Nas bordas, considera apenas os dias selecionados.',
                style: TextStyle(color: mutedInk))),
    ]));
  }

  Widget _ranking(String title, List rows) => SurfaceCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _heading(title),
        const Text('Ordenado por unidades; até 10 resultados.',
            style: TextStyle(color: mutedInk)),
        const SizedBox(height: 12),
        if (rows.isEmpty) const Text('Sem vendas neste período.'),
        ...rows.take(10).map((row) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(row['label'] as String,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(
                  '${row['quantity']} unidades · ${money(row['value_centavos'] as int)}',
                  style: const TextStyle(color: mutedInk)),
              const SizedBox(height: 7),
              LinearProgressIndicator(
                  value: (row['quantity'] as int) /
                      math.max(1, rows.first['quantity'] as int),
                  color: success,
                  backgroundColor: canvas,
                  minHeight: 6),
            ]))),
      ]));

  Widget _data(Map<String, dynamic> report) {
    final current = report['current'] as Map;
    final previous = report['previous'] as Map;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(
          'Comparação: ${_date(DateTime.parse(report['previous_from'] as String))} a '
          '${_date(DateTime.parse(report['previous_to'] as String))} · ${report['days']} dias em cada período.',
          style: const TextStyle(color: mutedInk)),
      const SizedBox(height: 16),
      _kpis(current, previous),
      const SizedBox(height: 16),
      _chart(current),
      const SizedBox(height: 16),
      LayoutBuilder(builder: (context, constraints) {
        final products =
            _ranking('Produtos mais vendidos', current['products'] as List);
        final flavors =
            _ranking('Combinações de pastéis', current['flavors'] as List);
        return constraints.maxWidth >= 1000
            ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: products),
                const SizedBox(width: 16),
                Expanded(child: flavors),
              ])
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [products, const SizedBox(height: 16), flavors]);
      }),
      const SizedBox(height: 16),
      _ranking(
          'Vendas por categoria',
          (current['categories'] as List)
              .map((row) => {
                    ...Map<String, dynamic>.from(row as Map),
                    'label': const {
                          'pastel': 'Pastéis',
                          'bebida': 'Bebidas',
                          'salgado': 'Salgados'
                        }[row['label']] ??
                        row['label'],
                  })
              .toList()),
      const SizedBox(height: 16),
      SurfaceCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _heading('Situação dos pedidos'),
        Text(
            '${current['closed_orders']} encerrados · ${current['open_orders']} em atendimento · '
            '${current['cancelled_orders']} cancelados',
            style: const TextStyle(fontSize: 18)),
        const SizedBox(height: 10),
        Text(
            'Valor cancelado: ${money(current['cancelled_value_centavos'] as int)}'),
        const SizedBox(height: 16),
        const Text(
            'Valor dos pedidos e ticket médio excluem pedidos e unidades cancelados. '
            'Incluem pedidos em atendimento. Não representam pagamentos recebidos nem lucro.',
            style: TextStyle(color: mutedInk)),
        if (current['legacy_orders'] > 0)
          Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                  '${current['legacy_orders']} pedidos do histórico importado. '
                  'O encerramento feito na migração não confirma pagamento.',
                  style: const TextStyle(color: mutedInk))),
        const SizedBox(height: 10),
        Text(
            'Atualizado em ${DateFormat('dd/MM/yyyy HH:mm').format(tz.TZDateTime.from(DateTime.parse(report['generated_at'] as String), tz.getLocation('America/Sao_Paulo')))} · São Paulo',
            style: const TextStyle(color: mutedInk)),
      ])),
    ]);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('BI · Visão do negócio'), actions: [
        IconButton(
            tooltip: 'Atualizar BI',
            onPressed: () => setState(_load),
            icon: const Icon(Icons.refresh)),
      ]),
      body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1400),
              child: ListView(padding: const EdgeInsets.all(20), children: [
                Wrap(spacing: 8, runSpacing: 8, children: [
                  ..._presets.map((preset) => ChoiceChip(
                      label: Text(preset),
                      selected: _preset == preset,
                      onSelected: (_) => _select(preset))),
                  ActionChip(
                      avatar: const Icon(Icons.date_range, size: 18),
                      label: const Text('Escolher período'),
                      onPressed: _custom),
                ]),
                const SizedBox(height: 16),
                Text('${_date(_from)} a ${_date(_to)}',
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 14),
                FutureBuilder<Map<String, dynamic>>(
                    future: _report,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Padding(
                            padding: EdgeInsets.all(48),
                            child: Center(child: CircularProgressIndicator()));
                      }
                      if (snapshot.hasError) {
                        return SurfaceCard(
                            child: Column(children: [
                          const Text('Não foi possível carregar o BI.',
                              style: TextStyle(
                                  fontSize: 21, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 12),
                          Text('${snapshot.error}'),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                              onPressed: () => setState(_load),
                              icon: const Icon(Icons.refresh),
                              label: const Text('Tentar novamente')),
                        ]));
                      }
                      return _data(snapshot.data!);
                    }),
              ]))));
}
