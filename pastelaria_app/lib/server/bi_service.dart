import 'dart:convert';
import 'package:timezone/timezone.dart' as tz;
import 'order_store.dart';
import '../models/pastel_extra.dart';

/// Read-only analytics over a consistent snapshot. Money stays in integer cents.
class BiService {
  final OrderStore store;
  BiService(this.store);

  static DateTime parseDay(String? value) {
    final parsed = value == null ? null : DateTime.tryParse(value);
    if (parsed == null ||
        !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value!) ||
        date(parsed) != value) {
      throw BusinessError('Informe datas válidas no formato AAAA-MM-DD.');
    }
    return DateTime.utc(parsed.year, parsed.month, parsed.day);
  }

  static String date(DateTime value) =>
      value.toIso8601String().substring(0, 10);

  Future<Map<String, dynamic>> report(String? from, String? to) async {
    final start = parseDay(from);
    final end = parseDay(to);
    final days = end.difference(start).inDays + 1;
    if (days < 1 || days > 366) {
      throw BusinessError('Selecione um período de 1 a 366 dias.');
    }
    final previousStart = start.subtract(Duration(days: days));
    final snapshot = await store.db.transaction((tx) async {
      final revision =
          (await tx.query('meta', where: 'key = ?', whereArgs: ['revision']))
              .single['value'];
      final rows = await tx.query('orders',
          columns: ['day', 'data'],
          where: 'day >= ? AND day <= ?',
          whereArgs: [date(previousStart), date(end)],
          orderBy: 'id');
      return {'revision': revision, 'rows': rows};
    });
    // Release the database transaction before computing the charts.
    final current = <Map<String, dynamic>>[];
    final previous = <Map<String, dynamic>>[];
    for (final row in snapshot['rows'] as List) {
      final order = jsonDecode(row['data'] as String) as Map<String, dynamic>;
      order['_day'] = row['day'];
      ((row['day'] as String).compareTo(date(start)) < 0 ? previous : current)
          .add(order);
    }
    return {
      'from': date(start),
      'to': date(end),
      'days': days,
      'previous_from': date(previousStart),
      'previous_to': date(start.subtract(const Duration(days: 1))),
      'timezone': 'America/Sao_Paulo',
      'revision': int.parse(snapshot['revision'] as String),
      'generated_at': store.now().toUtc().toIso8601String(),
      'current': summarize(current, start, end),
      'previous': summarize(
          previous, previousStart, start.subtract(const Duration(days: 1))),
    };
  }

  static Map<String, dynamic> summarize(
      List<Map<String, dynamic>> orders, DateTime start, DateTime end) {
    Map<String, dynamic> bucket(String label) =>
        {'label': label, 'value_centavos': 0, 'orders': 0, 'quantity': 0};
    void increment(Map<String, dynamic> row, int amount, int quantity,
        {int orders = 1}) {
      row['value_centavos'] = (row['value_centavos'] as int) + amount;
      row['quantity'] = (row['quantity'] as int) + quantity;
      row['orders'] = (row['orders'] as int) + orders;
    }

    String week(DateTime d) => date(d.subtract(Duration(days: d.weekday - 1)));
    final daily = <String, Map<String, dynamic>>{};
    final weekly = <String, Map<String, dynamic>>{};
    final monthly = <String, Map<String, dynamic>>{};
    for (var d = start; !d.isAfter(end); d = d.add(const Duration(days: 1))) {
      daily[date(d)] = bucket(date(d));
      weekly.putIfAbsent(week(d), () => bucket(week(d)));
      final month = date(d).substring(0, 7);
      monthly.putIfAbsent(month, () => bucket(month));
    }
    final hourly =
        List.generate(24, (h) => bucket('${h.toString().padLeft(2, '0')}h'));
    const dayNames = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
    final weekdays = dayNames.map(bucket).toList();
    final products = <String, Map<String, dynamic>>{};
    final flavors = <String, Map<String, dynamic>>{};
    final categories = <String, Map<String, dynamic>>{};
    var value = 0, quantity = 0, valid = 0, cancelled = 0, cancelledValue = 0;
    var open = 0, closed = 0, legacy = 0;
    for (final order in orders) {
      if (order['legacy'] != null) legacy++;
      var orderValue = 0, orderQuantity = 0;
      final isCancelled = order['status'] == 'cancelado';
      if (isCancelled) {
        cancelled++;
      } else {
        valid++;
        order['status'] == 'fechado' ? closed++ : open++;
      }
      for (final item in order['itens'] as List) {
        final requested = item['quantidade'] as int;
        final excluded =
            isCancelled ? requested : item['quantidade_cancelada'] as int;
        final unit = item['preco_unitario_centavos'] as int;
        cancelledValue += excluded * unit;
        final count = requested - excluded;
        if (count == 0) continue;
        final amount = count * unit;
        orderValue += amount;
        orderQuantity += count;
        final name = item['produto_nome'] as String;
        final type = item['produto_tipo'] as String;
        increment(products.putIfAbsent(name, () => bucket(name)), amount, count,
            orders: 0);
        increment(
            categories.putIfAbsent(type, () => bucket(type)), amount, count,
            orders: 0);
        if (type == 'pastel') {
          // Each combination is one flavor; do not multiply its value by ingredients.
          final ingredients = (item['ingredientes'] as List)
              .map((v) => v.toString())
              .toList()
            ..sort();
          final flavor =
              (ingredients.isEmpty ? name : ingredients.join(' + ')) +
                  PastelExtra.parse(item['adicionais'])
                      .map((extra) => ' + adicional: ${extra.name}')
                      .join();
          increment(
              flavors.putIfAbsent(flavor, () => bucket(flavor)), amount, count,
              orders: 0);
        }
      }
      if (isCancelled) continue;
      value += orderValue;
      quantity += orderQuantity;
      final day = order['_day'] as String;
      final d = parseDay(day);
      increment(daily[day]!, orderValue, orderQuantity);
      increment(weekly[week(d)]!, orderValue, orderQuantity);
      increment(monthly[day.substring(0, 7)]!, orderValue, orderQuantity);
      increment(weekdays[d.weekday - 1], orderValue, orderQuantity);
      final time = tz.TZDateTime.from(
          DateTime.parse(order['data_hora_pedido'] as String),
          tz.getLocation('America/Sao_Paulo'));
      increment(hourly[time.hour], orderValue, orderQuantity);
    }
    List<Map<String, dynamic>> ranked(Map<String, Map<String, dynamic>> map) =>
        map.values.toList()
          ..sort((a, b) {
            final comparison =
                (b['quantity'] as int).compareTo(a['quantity'] as int);
            return comparison == 0
                ? (a['label'] as String).compareTo(b['label'] as String)
                : comparison;
          });
    return {
      'value_centavos': value,
      'orders': valid,
      'quantity': quantity,
      'ticket_centavos': valid == 0 ? 0 : (value / valid).round(),
      'cancelled_orders': cancelled,
      'cancelled_value_centavos': cancelledValue,
      'open_orders': open,
      'closed_orders': closed,
      'legacy_orders': legacy,
      'daily': daily.values.toList(),
      'weekly': weekly.values.toList(),
      'monthly': monthly.values.toList(),
      'hourly': hourly,
      'weekdays': weekdays,
      'products': ranked(products),
      'flavors': ranked(flavors),
      'categories': ranked(categories),
    };
  }
}
