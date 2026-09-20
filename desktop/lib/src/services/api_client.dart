import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models.dart';

class ApiFailure implements Exception {
  const ApiFailure(this.message, {this.status, this.code});
  final String message;
  final int? status;
  final String? code;
  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();
  static const _serverKey = 'server_url';
  static const _cookieKey = 'boohtacord_session_cookie';
  final http.Client _client;
  final FlutterSecureStorage _storage = Platform.isMacOS
      ? const FlutterSecureStorage(
          mOptions: MacOsOptions(usesDataProtectionKeychain: false),
        )
      : const FlutterSecureStorage();
  String baseUrl = 'https://v.bootybay.ru/api/v1';

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
    await _storage.delete(key: _cookieKey);
  }

  Future<Map<String, String>> _headers({bool jsonBody = false}) async {
    final cookie = await _storage.read(key: _cookieKey);
    final server = Uri.parse(baseUrl);
    return {
      'accept': 'application/json',
      'origin': '${server.scheme}://${server.authority}',
      if (jsonBody) 'content-type': 'application/json',
      'cookie': ?cookie,
    };
  }

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('$baseUrl$path').replace(queryParameters: query);

  Future<dynamic> _checked(http.Response response) async {
    final setCookie = response.headers['set-cookie'];
    if (setCookie != null) {
      final pair = setCookie.split(';').first;
      if (pair.endsWith('=')) {
        await _storage.delete(key: _cookieKey);
      } else {
        await _storage.write(key: _cookieKey, value: pair);
      }
    }
    dynamic decoded;
    if (response.body.isNotEmpty) {
      try {
        decoded = jsonDecode(response.body);
      } catch (_) {
        decoded = null;
      }
    }
    if (response.statusCode >= 200 && response.statusCode < 300) return decoded;
    String? code;
    String? message;
    if (decoded is Map<String, dynamic> &&
        decoded['error'] is Map<String, dynamic>) {
      final error = decoded['error'] as Map<String, dynamic>;
      code = error['code'] as String?;
      message = error['message'] as String?;
    }
    throw ApiFailure(
      message ?? 'Запрос отклонён сервером (${response.statusCode}).',
      status: response.statusCode,
      code: code,
    );
  }

  Future<SessionUser?> currentSession() async {
    final response = await _client.get(
      _uri('/auth/session'),
      headers: await _headers(),
    );
    if (response.statusCode == 401) return null;
    final data = await _checked(response) as Map<String, dynamic>;
    if (data['authenticated'] == false) return null;
    return SessionUser.fromJson(data);
  }

  Future<void> authenticate(
    String login,
    String password, {
    required bool register,
  }) async {
    final body = jsonEncode({'login': login, 'password': password});
    if (register) {
      await _checked(
        await _client.post(
          _uri('/auth/register'),
          headers: await _headers(jsonBody: true),
          body: body,
        ),
      );
    }
    await _checked(
      await _client.post(
        _uri('/auth/login'),
        headers: await _headers(jsonBody: true),
        body: body,
      ),
    );
  }

  Future<void> logout() async {
    try {
      await _checked(
        await _client.post(_uri('/auth/logout'), headers: await _headers()),
      );
    } finally {
      await _storage.delete(key: _cookieKey);
    }
  }

  Future<ChannelTopology> topology() async {
    final data = await _checked(
      await _client.get(_uri('/channels'), headers: await _headers()),
    ) as Map<String, dynamic>;
    return ChannelTopology.fromJson(data);
  }

  Future<List<ChatMessage>> messages(String channelId) async {
    final data = await _checked(
      await _client.get(
        _uri('/channels/$channelId/messages'),
        headers: await _headers(),
      ),
    ) as Map<String, dynamic>;
    final values = (data['messages'] as List<dynamic>)
        .map((value) => ChatMessage.fromJson(value as Map<String, dynamic>))
        .toList();
    values.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return values;
  }

  Future<ChatMessage> sendMessage(
    String channelId,
    String clientMessageId,
    String body,
  ) async {
    final response = await _client.post(
      _uri('/channels/$channelId/messages'),
      headers: await _headers(jsonBody: true),
      body: jsonEncode({'client_message_id': clientMessageId, 'body': body}),
    );
    return ChatMessage.fromJson(
      await _checked(response) as Map<String, dynamic>,
    );
  }

  Future<(String, VoiceCredential)> voiceCredential(
    String channelId, {
    bool transfer = false,
  }) async {
    final leaseData = await _checked(
      await _client.post(
        _uri('/voice/channels/$channelId/leases'),
        headers: await _headers(jsonBody: true),
        body: jsonEncode({'transfer': transfer}),
      ),
    ) as Map<String, dynamic>;
    final leaseId = leaseData['id'] as String;
    final credential = await _checked(
      await _client.post(
        _uri('/voice/leases/$leaseId/credential'),
        headers: await _headers(),
      ),
    ) as Map<String, dynamic>;
    return (
      leaseId,
      VoiceCredential(
        url: credential['url'] as String,
        token: credential['token'] as String,
      ),
    );
  }

  Future<void> releaseVoice(String leaseId) async {
    await _checked(
      await _client.delete(
        _uri('/voice/leases/$leaseId'),
        headers: await _headers(),
      ),
    );
  }
}
