import 'package:flutter/foundation.dart';

class LogService extends ChangeNotifier {
  final List<String> _logs = [];

  List<String> get logs => List.unmodifiable(_logs);

  void add(String message) {
    final timestamp = DateTime.now().toIso8601String();
    _logs.add('[$timestamp] $message');
    if (_logs.length > 500) _logs.removeRange(0, _logs.length - 500);
    notifyListeners();
  }

  void clear() {
    _logs.clear();
    notifyListeners();
  }
}

final logService = LogService();
