import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../http/api_failure.dart';
import '../platform/session_storage.dart';
import 'scope.dart';
import '../../features/telemetry/action_scope/session.dart';

class SessionStore {
  SessionStore() : _storage = sessionStorage();
  static const _serverKey = 'server_url';
  static const _legacyCookieKey = 'boohtacord_session_cookie';
  static const _cookieKeyPrefix = 'boohtacord_session_cookie:';
  final FlutterSecureStorage _storage;
  late final SessionScope scope = SessionScope(
    onBoundary: () => telemetry.reset(),
  );
  late final TelemetrySession telemetry = TelemetrySession(
    scope.capture,
    () => _baseUrl,
  );
  Future<void> _cookieWrites = Future<void>.value();
  String _baseUrl = 'https://v.bootybay.ru/api/v1';
  int serverRevision = 0;
  String get baseUrl => _baseUrl;
  set baseUrl(String value) {
    if (_baseUrl != value) {
      serverRevision++;
      telemetry.reset();
    }
    _baseUrl = value;
  }

  void Function()? onUnauthorized;
  Future<String?> readCookie() async {
    await _cookieWrites;
    return _storage.read(key: _cookieKeyFor(_baseUrl));
  }

  Future<void> clearCookie({SessionTicket? ticket}) => _write(() {
    telemetry.reset();
    return _storage.delete(key: _cookieKeyFor(_baseUrl));
  }, ticket);
  Future<void> writeCookie(String value, {SessionTicket? ticket}) =>
      _write(() => _storage.write(key: _cookieKeyFor(_baseUrl), value: value), ticket);
  Future<void> _write(Future<void> Function() action, SessionTicket? ticket) {
    final admitted = ticket ?? scope.capture();
    final server = serverRevision;
    final next = _cookieWrites.then((_) async {
      if (admitted.isCurrent && server == serverRevision) await action();
    });
    _cookieWrites = next.catchError((Object _) {});
    return next;
  }

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    // The old key had no origin metadata, so its destination cannot be proven.
    // Discard it rather than attaching an ambiguous credential to a server.
    await _storage.delete(key: _legacyCookieKey);
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
    final previousCookieKey = _cookieKeyFor(_baseUrl);
    final nextCookieKey = _cookieKeyFor(normalized);
    await _cookieWrites;
    // Invalidate both sides before persisting/publishing the new server. If a
    // secure-storage operation fails, the caller remains unauthenticated.
    await _storage.delete(key: previousCookieKey);
    if (nextCookieKey != previousCookieKey) {
      await _storage.delete(key: nextCookieKey);
    }
    await _storage.delete(key: _legacyCookieKey);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_serverKey, normalized);
    baseUrl = normalized;
  }

  String _cookieKeyFor(String server) {
    final uri = Uri.parse(server);
    final port = uri.hasPort ? uri.port : 443;
    return '$_cookieKeyPrefix${uri.scheme.toLowerCase()}://${uri.host.toLowerCase()}:$port';
  }
}
