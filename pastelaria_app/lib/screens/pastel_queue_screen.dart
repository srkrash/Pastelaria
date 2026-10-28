import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timezone/timezone.dart' as tz;
import '../providers/pedidos_provider.dart';
import '../services/api_service.dart';
import '../ui/app_ui.dart';
import '../models/pastel_extra.dart';

/// Kitchen work list: one pending combination at a time, by arrival order.
/// It only records existing ready quantities; there is no implicit delivery.
class PastelQueueScreen extends StatefulWidget {
  final ApiService? api;
  const PastelQueueScreen({super.key, this.api});
  @override
  State<PastelQueueScreen> createState() => _PastelQueueScreenState();
}

class _KitchenTask {
  final Map<String, dynamic> order, item;
  _KitchenTask(this.order, this.item);
  int get remaining =>
      (item['quantidade'] as int) -
      (item['quantidade_cancelada'] as int) -
      (item['quantidade_pronta'] as int);
  String get ticket =>
      'Senha ${order['numero_pedido'].toString().padLeft(2, '0')}';
  String get flavor =>
      ((item['ingredientes'] as List).isEmpty
          ? item['produto_nome'] as String
          : (item['ingredientes'] as List).join(' + ')) +
      PastelExtra.parse(item['adicionais'])
          .map((extra) => ' + adicional: ${extra.name}')
          .join();
  String get key => '${order['pedido_id']}:${item['item_id']}';
}

class _PastelQueueScreenState extends State<PastelQueueScreen> {
  String? _busy;
  bool _sending = false;
  List<_KitchenTask> _tasks(PedidosProvider provider) {
    final orders = provider.filaProducao.toList()
      ..sort((a, b) {
        final first =
            DateTime.tryParse(a['data_hora_pedido']?.toString() ?? '');
        final second =
            DateTime.tryParse(b['data_hora_pedido']?.toString() ?? '');
        final comparison =
            first != null && second != null ? first.compareTo(second) : 0;
        return comparison == 0
            ? (a['pedido_id'] as int).compareTo(b['pedido_id'] as int)
            : comparison;
      });
    final tasks = <_KitchenTask>[];
    for (final order in orders) {
      final items = (order['itens'] as List)
          .map((raw) => Map<String, dynamic>.from(raw as Map))
          .where((i) => i['produto_tipo'] == 'pastel')
          .toList()
        ..sort((a, b) => (a['item_id'] as int).compareTo(b['item_id'] as int));
      for (final item in items) {
        final task = _KitchenTask(order, item);
        if (task.remaining > 0) tasks.add(task);
      }
    }
    return tasks;
  }

  Future<void> _ready(_KitchenTask task, {bool all = true}) async {
    if (_busy != null) return;
    setState(() => _busy = task.key);
    final provider = context.read<PedidosProvider>();
    try {
      var quantity = 1;
      final count = all
          ? task.remaining
          : await showDialog<int>(
              context: context,
              builder: (dialogContext) => StatefulBuilder(
                  builder: (context, update) => AlertDialog(
                        title: const Text('Quantos ficaram prontos?'),
                        content: SingleChildScrollView(
                            child: SizedBox(
                                width: 420,
                                child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(task.ticket,
                                          style: const TextStyle(
                                              fontSize: 25,
                                              fontWeight: FontWeight.w800)),
                                      const SizedBox(height: 12),
                                      Text(task.flavor,
                                          style: const TextStyle(
                                              fontSize: 23,
                                              fontWeight: FontWeight.w800)),
                                      if ((task.item['observacoes_item'] ?? '')
                                          .toString()
                                          .isNotEmpty)
                                        Padding(
                                            padding:
                                                const EdgeInsets.only(top: 12),
                                            child: Text(
                                                'Atenção: ${task.item['observacoes_item']}',
                                                style: const TextStyle(
                                                    color: brand,
                                                    fontSize: 20,
                                                    fontWeight:
                                                        FontWeight.w700))),
                                      const SizedBox(height: 20),
                                      Center(
                                          child: QuantityStepper(
                                              value: quantity,
                                              max: task.remaining,
                                              onChanged: (value) => update(
                                                  () => quantity = value))),
                                      const SizedBox(height: 10),
                                      TextButton(
                                          onPressed: () => update(
                                              () => quantity = task.remaining),
                                          child: Text(
                                              'Selecionar todo o saldo: ${task.remaining}')),
                                      const Text(
                                          'Registre somente as unidades com preparo concluído. O saldo continua nesta fila.',
                                          style: TextStyle(color: mutedInk)),
                                    ]))),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              child: const Text('Voltar')),
                          FilledButton(
                              onPressed: () =>
                                  Navigator.pop(dialogContext, quantity),
                              child: const Text('Confirmar preparo'))
                        ],
                      )));
      if (count == null || !mounted) return;
      setState(() => _sending = true);
      // Keep the captured revision: the server rejects a stale concurrent edit.
      await (widget.api ?? ApiService())
          .changeQuantity(task.order, task.item['item_id'] as int, count, true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      await provider.refresh();
      if (mounted) {
        setState(() {
          _busy = null;
          _sending = false;
        });
      }
    }
  }

  Widget _notice(String label, String text) => Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: const Color(0xFFFFE8D9),
          border: Border.all(color: brand, width: 2),
          borderRadius: BorderRadius.circular(12)),
      child: Text('$label: $text',
          style: const TextStyle(
              color: brand, fontSize: 23, fontWeight: FontWeight.w800)));

  Widget _next(_KitchenTask task, PedidosProvider provider) {
    final count = Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            color: brand, borderRadius: BorderRadius.circular(16)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('${task.remaining}',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 64,
                  fontWeight: FontWeight.w900)),
          Text(task.remaining == 1 ? 'PASTEL A FAZER' : 'PASTÉIS A FAZER',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800)),
        ]));
    final ingredients =
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('RECHEIO',
          style: TextStyle(
              color: mutedInk,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: 2)),
      const SizedBox(height: 8),
      Text(task.flavor,
          style: const TextStyle(
              fontSize: 34, fontWeight: FontWeight.w900, height: 1.2)),
      const SizedBox(height: 12),
      Text(
          '${task.item['quantidade_pronta']} já prontos · ${task.item['quantidade']} no pedido',
          style: const TextStyle(color: mutedInk, fontSize: 17)),
    ]);
    final itemNote = (task.item['observacoes_item'] ?? '').toString().trim();
    final orderNote = (task.order['observacoes'] ?? '').toString().trim();
    final instant =
        DateTime.tryParse(task.order['data_hora_pedido']?.toString() ?? '');
    final at = instant == null
        ? null
        : tz.TZDateTime.from(instant, tz.getLocation('America/Sao_Paulo'));
    return Container(
        key: ValueKey('next-${task.key}'),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: brand, width: 3),
            borderRadius: BorderRadius.circular(20)),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Wrap(
              spacing: 12,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const StatusPill('MONTAR AGORA',
                    color: brand, icon: Icons.restaurant),
                Text(task.ticket,
                    style: const TextStyle(
                        fontSize: 30, fontWeight: FontWeight.w900)),
                Text(
                    'Pedido ${task.order['pedido_id']}${at == null ? '' : ' · ${clockTime(at)}'}',
                    style: const TextStyle(color: mutedInk, fontSize: 17)),
              ]),
          const SizedBox(height: 20),
          LayoutBuilder(
              builder: (context, constraints) => constraints.maxWidth >= 540
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                          SizedBox(width: 160, child: count),
                          const SizedBox(width: 24),
                          Expanded(child: ingredients),
                        ])
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                          count,
                          const SizedBox(height: 18),
                          ingredients,
                        ])),
          if (itemNote.isNotEmpty) ...[
            const SizedBox(height: 18),
            _notice('ATENÇÃO AO PASTEL', itemNote)
          ],
          if (orderNote.isNotEmpty) ...[
            const SizedBox(height: 12),
            _notice('PEDIDO', orderNote)
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
              onPressed: provider.error == null && _busy == null
                  ? () => _ready(task)
                  : null,
              style: FilledButton.styleFrom(minimumSize: const Size(0, 64)),
              icon: _sending && _busy == task.key
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.check_circle_outline),
              label: const Text('Definir como pronto')),
          const SizedBox(height: 8),
          TextButton(
              onPressed: provider.error == null && _busy == null
                  ? () => _ready(task, all: false)
                  : null,
              child: const Text('Informar quantidade')),
        ]));
  }

  Widget _upcoming(_KitchenTask task, int position) => SurfaceCard(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(
            spacing: 12,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('$positionº',
                  style: const TextStyle(
                      color: mutedInk,
                      fontSize: 21,
                      fontWeight: FontWeight.w800)),
              Text('${task.remaining}×',
                  style: const TextStyle(
                      color: brand, fontSize: 34, fontWeight: FontWeight.w900)),
              Text(task.ticket,
                  style: const TextStyle(
                      fontSize: 21, fontWeight: FontWeight.w800)),
            ]),
        const SizedBox(height: 8),
        Text(task.flavor,
            style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800)),
        if ((task.item['observacoes_item'] ?? '').toString().isNotEmpty)
          Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text('ATENÇÃO: ${task.item['observacoes_item']}',
                  style: const TextStyle(
                      color: brand,
                      fontSize: 20,
                      fontWeight: FontWeight.w700))),
        if ((task.order['observacoes'] ?? '').toString().isNotEmpty)
          Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('Pedido: ${task.order['observacoes']}',
                  style: const TextStyle(color: mutedInk, fontSize: 17))),
      ]));

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PedidosProvider>();
    final tasks = _tasks(provider);
    final count = tasks.fold<int>(0, (sum, task) => sum + task.remaining);
    return Scaffold(
        appBar: AppBar(title: const Text('Produção de pastéis'), actions: [
          IconButton(
              tooltip: 'Sincronizar cozinha',
              onPressed: provider.refresh,
              icon: const Icon(Icons.refresh)),
        ]),
        body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            children: [
              if (provider.error != null)
                Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: SurfaceCard(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(
                              '${provider.error}\nFila sem confirmação de atualização.',
                              style: const TextStyle(
                                  color: brand,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700)),
                          TextButton(
                              onPressed: provider.refresh,
                              child: const Text('Tentar novamente')),
                        ]))),
              Wrap(spacing: 12, runSpacing: 8, children: [
                StatusPill(
                    '$count ${count == 1 ? 'pastel' : 'pastéis'} para preparar',
                    color: brand),
                Text(
                    '${provider.filaProducao.length} pedidos · ${tasks.length} itens na sequência',
                    style: const TextStyle(color: mutedInk, fontSize: 17)),
              ]),
              const SizedBox(height: 14),
              if (tasks.isEmpty)
                Padding(
                    padding: const EdgeInsets.symmetric(vertical: 60),
                    child: Column(children: [
                      if (provider.loading)
                        const CircularProgressIndicator()
                      else
                        Icon(
                            provider.error == null
                                ? Icons.task_alt
                                : Icons.wifi_off,
                            size: 64,
                            color: mutedInk),
                      const SizedBox(height: 20),
                      Text(
                          provider.error != null
                              ? 'Não foi possível confirmar a fila.'
                              : provider.loading
                                  ? 'Carregando a cozinha…'
                                  : 'Tudo preparado. Aguardando novos pastéis.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 23, fontWeight: FontWeight.w700)),
                    ])),
              if (tasks.isNotEmpty) ...[
                _next(tasks.first, provider),
                const SizedBox(height: 22),
                Text(
                    tasks.length > 1
                        ? 'NA SEQUÊNCIA'
                        : 'Este é o último item da fila.',
                    style: const TextStyle(
                        fontSize: 21, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                const Text(
                    'Por ordem de chegada. Cada recheio e observação fica separado.',
                    style: TextStyle(color: mutedInk)),
                for (var index = 1; index < tasks.length; index++) ...[
                  const SizedBox(height: 12),
                  _upcoming(tasks[index], index + 1),
                ],
              ],
            ]));
  }
}
