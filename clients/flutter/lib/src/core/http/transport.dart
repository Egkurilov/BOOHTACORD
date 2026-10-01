import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../services/tracing_http_client.dart';
import '../session/session_store.dart';
import 'api_failure.dart';

class ApiTransport {
  ApiTransport({http.Client? client}) : raw = client ?? http.Client() {
    this.client = TracingHttpClient(raw);
  }
  final http.Client raw;
  late final http.Client client;
  final SessionStore session = SessionStore();

  Map<String, String> publicHeaders({String accept = 'application/json'}) {
    final server = Uri.parse(session.baseUrl);
    return {
      'accept': accept,
      'origin': '${server.scheme}://${server.authority}',
    };
  }

  Future<Map<String, String>> headers({
    bool jsonBody = false,
    String accept = 'application/json',
  }) async {
    final cookie = await session.readCookie();
    return {
      ...publicHeaders(accept: accept),
      if (jsonBody) 'content-type': 'application/json',
      'cookie': ?cookie,
    };
  }

  Uri uri(String path, [Map<String, String>? query]) =>
      Uri.parse('${session.baseUrl}$path').replace(queryParameters: query);

  Future<dynamic> checked(
    http.Response response, {
    bool reportUnauthorized = true,
  }) async {
    final setCookie = response.headers['set-cookie'];
    if (setCookie != null) {
      final pair = setCookie.split(';').first;
      if (pair.endsWith('=')) {
        await session.clearCookie();
      } else {
        await session.writeCookie(pair);
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
    if (response.statusCode == 401) {
      await session.clearCookie();
      if (reportUnauthorized) session.onUnauthorized?.call();
    }
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
}
