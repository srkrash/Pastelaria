import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class IpStorage {
  static const _key = 'server_ip';

  /// Salva o IP no dispositivo
  static Future<void> saveIp(String ip) async {
    debugPrint('IpStorage: Salvando IP $ip');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, ip);
  }

  /// Lê o IP salvo (retorna null se não existir)
  static Future<String?> getIp() async {
    final prefs = await SharedPreferences.getInstance();
    final ip = prefs.getString(_key);
    debugPrint('IpStorage: IP recuperado: $ip');
    return ip;
  }
}
