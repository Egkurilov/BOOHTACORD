import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../http/api_failure.dart';
import '../platform/session_storage.dart';

class SessionStore {
  SessionStore() : _storage = sessionStorage();
  static const _serverKey = 'server_url';
  static const _cookieKey = 'boohtacord_session_cookie';
  final FlutterSecureStorage _storage;
  String baseUrl = 'https://v.bootybay.ru/api/v1';
  void Function()? onUnauthorized;
  Future<String?> readCookie() => _storage.read(key: _cookieKey);
  Future<void> clearCookie() => _storage.delete(key: _cookieKey);
  Future<void> writeCookie(String value) =>
      _storage.write(key: _cookieKey, value: value);

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    baseUrl = prefs.getString(_serverKey) ?? baseUrl;
  }

  Future<void> setBaseUrl(String value) async {
    var normalized = value.trim();
    if (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    if (!normalized.endsWith('/api/v1')) normalized = '$normalized/api/v1';
    final uri = Uri.tryParse(normalized);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      throw const ApiFailure(
        'Укажите HTTPS-адрес сервера, например https://guild.example.com.',
      );
    }
    baseUrl = normalized;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_serverKey, baseUrl);
    await clearCookie();
  }
}
