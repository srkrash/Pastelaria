import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/log_service.dart';

class LogScreen extends StatelessWidget {
  const LogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Logs do Sistema"),
      ),
      body: Consumer<LogService>(
        builder: (context, logService, _) {
          if (logService.logs.isEmpty) {
            return const Center(
              child: Text("Nenhum log ainda."),
            );
          }

          return ListView.builder(
            itemCount: logService.logs.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(logService.logs[index]),
              );
            },
          );
        },
      ),
    );
  }
}
