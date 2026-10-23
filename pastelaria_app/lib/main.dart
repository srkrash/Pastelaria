import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'providers/pedidos_provider.dart';
import 'screens/main_screen.dart';
import 'services/app_settings.dart';
import 'services/log_service.dart';
import 'server/server_runtime.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  final settings = await AppSettings.load();
  if (settings.host && settings.configured) {
    try {
      await ServerRuntime.instance.configure(settings);
    } catch (_) {
      logService.add(
          'Falha ao iniciar servidor local. Abra Configurações para tentar novamente.');
    }
  }
  final provider = await PedidosProvider.create();
  runApp(MultiProvider(providers: [
    ChangeNotifierProvider.value(value: provider),
    ChangeNotifierProvider.value(value: logService)
  ], child: MyApp(initialRole: settings.role)));
}

class MyApp extends StatelessWidget {
  final String initialRole;
  const MyApp({super.key, this.initialRole = 'pedido'});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Pastelaria Gaúcha',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
            useMaterial3: true,
            inputDecorationTheme:
                const InputDecorationTheme(border: OutlineInputBorder())),
        home: MainScreen(initialRole: initialRole),
      );
}
