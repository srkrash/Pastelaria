import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../server/pix_payment.dart';

String newCommandId() => base64UrlEncode(
    List<int>.generate(24, (_) => Random.secure().nextInt(256)));

class AppSettings {
  final bool host;
  final String address;
  final String secret;
  final String printerAddress;
  final int printerPort;
  final String role;
  final bool pixEnabled;
  final String pixPhone, pixName, pixCity;
  const AppSettings(
      {this.host = false,
      this.address = '',
      this.secret = '',
      this.printerAddress = '',
      this.printerPort = 9100,
      this.pixEnabled = false,
      this.pixPhone = '',
      this.pixName = '',
      this.pixCity = '',
      this.role = 'pedido'});
  PixConfiguration? get pix => pixEnabled
      ? PixConfiguration(phone: pixPhone, name: pixName, city: pixCity)
      : null;
  String get baseUrl => 'http://${host ? '127.0.0.1' : address}:5000';
  bool get configured => secret.length >= 16 && (host || address.isNotEmpty);
  static Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AppSettings(
        host: prefs.getBool('host_v2') ?? false,
        address: prefs.getString('address_v2') ?? '',
        secret: prefs.getString('secret_v2') ?? '',
        printerAddress: prefs.getString('printer_v2') ?? '',
        printerPort: prefs.getInt('printer_port_v2') ?? 9100,
        pixEnabled: prefs.getBool('pix_enabled_v2') ?? false,
        pixPhone: prefs.getString('pix_phone_v2') ?? '',
        pixName: prefs.getString('pix_name_v2') ?? '',
        pixCity: prefs.getString('pix_city_v2') ?? '',
        role: prefs.getString('role_v2') ?? 'pedido');
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('host_v2', host);
    await prefs.setString('address_v2', address);
    await prefs.setString('secret_v2', secret);
    await prefs.setString('printer_v2', printerAddress);
    await prefs.setInt('printer_port_v2', printerPort);
    await prefs.setBool('pix_enabled_v2', pixEnabled);
    await prefs.setString('pix_phone_v2', pixPhone);
    await prefs.setString('pix_name_v2', pixName);
    await prefs.setString('pix_city_v2', pixCity);
    await prefs.setString('role_v2', role);
  }
}
