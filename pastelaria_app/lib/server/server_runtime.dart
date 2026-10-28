import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/app_settings.dart';
import '../services/api_service.dart';
import 'local_server.dart';
import 'order_store.dart';
import 'printer_worker.dart';
import 'backup_service.dart';

class ServerRuntime {
  static final instance = ServerRuntime();
  static const _channel = MethodChannel('pastelaria/server');
  LocalServer? server;
  OrderStore? store;
  PrinterWorker? _printer;
  String? error;
  String? backupError;
  Timer? _backupTimer;
  Future<File>? _backupTask;
  Future<String> recoveryKey() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString('backup_key_v2');
    if (existing != null) return existing;
    final key = BackupService.newKey();
    await prefs.setString('backup_key_v2', key);
    return key;
  }

  Future<Map<String, dynamic>> clearTodayTests(
      Map<String, dynamic> preview) async {
    if (store == null) throw StateError('Use o tablet principal.');
    final printer = _printer;
    await printer?.stop();
    try {
      return await ApiService().command('clear_today_tests', {
        ...preview,
        'confirmation': 'APAGAR TESTES DE HOJE',
      });
    } finally {
      await printer?.start();
    }
  }

  Future<File> backupNow() {
    if (_backupTask != null) return _backupTask!;
    final future = _createBackup();
    _backupTask = future;
    return future.whenComplete(() => _backupTask = null);
  }

  Future<File> _createBackup() async {
    final current = store;
    if (current == null) {
      throw StateError('Backup disponível no tablet principal.');
    }
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = await BackupService.create(current,
          Directory(p.join(directory.path, 'backups')), await recoveryKey());
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'last_backup_v2', DateTime.now().toUtc().toIso8601String());
      backupError = null;
      return file;
    } catch (_) {
      backupError = 'Falha no backup local; confira o armazenamento.';
      rethrow;
    }
  }

  Future<void> configure(AppSettings settings) async {
    _backupTimer?.cancel();
    if (_backupTask != null) {
      try {
        await _backupTask;
      } catch (_) {}
    }
    await _printer?.stop();
    await server?.stop();
    await store?.db.close();
    _printer = null;
    server = null;
    store = null;
    error = null;
    if (Platform.isAndroid) await _channel.invokeMethod<void>('stop');
    if (!settings.host) return;
    try {
      if (Platform.isAndroid) await _channel.invokeMethod<void>('start');
      final dir = await getApplicationDocumentsDirectory();
      final db = await openDatabase(p.join(dir.path, 'pastelaria_v2.db'),
          version: 1,
          onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
          onCreate: OrderStore.createSchema);
      store = OrderStore(db);
      await store!.seed(
          jsonDecode(await rootBundle.loadString('assets/catalogo.json'))
              as List);
      server = LocalServer(store!, settings.secret);
      await server!.start();
      _printer = PrinterWorker(
          store!, settings.printerAddress, settings.printerPort,
          pix: settings.pix);
      await _printer!.start();
      unawaited(backupNow().then<void>((_) {}, onError: (Object _) {}));
      _backupTimer = Timer.periodic(const Duration(hours: 1), (_) {
        unawaited(backupNow().then<void>((_) {}, onError: (Object _) {}));
      });
    } catch (e) {
      error = 'Não foi possível iniciar o servidor local: $e';
      await server?.stop();
      await store?.db.close();
      server = null;
      store = null;
      if (Platform.isAndroid) await _channel.invokeMethod<void>('stop');
      rethrow;
    }
  }
}
