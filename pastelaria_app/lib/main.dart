// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pastelaria_app/screens/main_screen.dart';
import 'providers/pedidos_provider.dart';
import 'package:flutter/foundation.dart';
import 'services/log_service.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

// 1. Torne o main() assíncrono
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  WakelockPlus.enable();

  // Intercepta TUDO que seria printado
  debugPrint = (String? message, {int? wrapWidth}) {
    if (message != null) {
      logService.add(message);
    }
    // Continua exibindo no console normalmente
    debugPrintSynchronously(message ?? "");
  };

  final pedidosProvider = await PedidosProvider.create();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: logService),
        ChangeNotifierProvider.value(value: pedidosProvider),
      ],
      child: MyApp(pedidosProvider: pedidosProvider),
    ),
  );
}

class MyApp extends StatelessWidget {
  // 4. Recebe a instância do Provider
  final PedidosProvider pedidosProvider;
  
  const MyApp({
    super.key, 
    required this.pedidosProvider, // Deve ser obrigatório, pois o app precisa dele
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // 5. Usa ChangeNotifierProvider.value para fornecer o objeto existente
        ChangeNotifierProvider.value(value: pedidosProvider),
      ],
      child: MaterialApp(
        title: 'Pastelaria App',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        home: const MainScreen(),
      ),
    );
  }
}