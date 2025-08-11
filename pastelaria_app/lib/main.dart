// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pastelaria_app/screens/main_screen.dart'; // Importe a nova tela
import 'providers/pedidos_provider.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PedidosProvider()),
      ],
      child: MaterialApp(
        title: 'Pastelaria App',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        home: const MainScreen(), // Defina MainScreen como a tela inicial
      ),
    );
  }
}