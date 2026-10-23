import 'package:flutter/material.dart';
import 'order_queue_screen.dart';

class PastelQueueScreen extends StatelessWidget {
  const PastelQueueScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const OrderQueueScreen(production: true);
}
