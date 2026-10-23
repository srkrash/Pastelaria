import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/item_pedido.dart';

const ink = Color(0xFF182D2A);
const mutedInk = Color(0xFF566862);
const brand = Color(0xFFB44324);
const canvas = Color(0xFFF5F5EF);
const success = Color(0xFF21664E);

ThemeData appTheme({String? fontFamily}) => ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: canvas,
      colorScheme: ColorScheme.fromSeed(
          seedColor: brand,
          primary: brand,
          secondary: success,
          surface: Colors.white,
          onSurface: ink),
      appBarTheme: AppBarTheme(
          backgroundColor: canvas,
          foregroundColor: ink,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
              fontFamily: fontFamily,
              color: ink,
              fontSize: 23,
              fontWeight: FontWeight.w700)),
      filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
              minimumSize: const Size(48, 54),
              textStyle: TextStyle(
                  fontFamily: fontFamily,
                  fontSize: 17,
                  fontWeight: FontWeight.w700),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)))),
      outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
              minimumSize: const Size(48, 52),
              textStyle: TextStyle(
                  fontFamily: fontFamily,
                  fontSize: 17,
                  fontWeight: FontWeight.w600),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)))),
      inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.all(16),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFCCD4CD)))),
      snackBarTheme:
          const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    );

String money(int cents) =>
    NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(cents / 100);
int pastelUnitCents(List<String> ingredients) {
  if (ingredients.length == 1 && ingredients.single == 'Pizza') return 1500;
  if (ingredients.length == 1 && ingredients.single == 'Misto') return 2500;
  final count = ingredients
      .where((s) => !['Cebola', 'Cebolinha', 'Orégano'].contains(s))
      .length;
  return 1200 + (count > 2 ? (count - 2) * 300 : 0);
}

int itemUnitCents(ItemPedido item) => item.produtoNome == 'Pastel'
    ? pastelUnitCents(item.ingredientes)
    : (item.preco * 100).round();

class SurfaceCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const SurfaceCard(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(20)});
  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE0E5DF))),
        child: child,
      );
}

class QuantityStepper extends StatelessWidget {
  final int value, min, max;
  final ValueChanged<int>? onChanged;
  final String label;
  const QuantityStepper(
      {super.key,
      required this.value,
      required this.onChanged,
      this.min = 1,
      this.max = 999,
      this.label = 'Quantidade'});
  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton.outlined(
            tooltip: 'Diminuir $label',
            onPressed: onChanged != null && value > min
                ? () => onChanged!(value - 1)
                : null,
            icon: const Icon(Icons.remove),
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48)),
        Semantics(
            label: '$label: $value',
            child: SizedBox(
                width: 56,
                child: Text('$value',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 23, fontWeight: FontWeight.w800)))),
        IconButton.outlined(
            tooltip: 'Aumentar $label',
            onPressed: onChanged != null && value < max
                ? () => onChanged!(value + 1)
                : null,
            icon: const Icon(Icons.add),
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48)),
      ]);
}

class StatusPill extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;
  const StatusPill(this.text, {super.key, this.color = success, this.icon});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
            color: color.withValues(alpha: .09),
            borderRadius: BorderRadius.circular(9)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[
            Icon(icon, size: 17, color: color),
            const SizedBox(width: 6)
          ],
          Flexible(
              child: Text(text,
                  style: TextStyle(
                      color: color, fontSize: 14, fontWeight: FontWeight.w700)))
        ]),
      );
}

String clockTime(DateTime date) =>
    "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
