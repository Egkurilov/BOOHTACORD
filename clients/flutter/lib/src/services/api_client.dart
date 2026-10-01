import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models.dart';
import 'client_telemetry.dart';
import 'tracing_http_client.dart';

class ApiFailure implements Exception {
  const ApiFailure(this.message, {this.status, this.code});
  final String message;
  final int? status;
  final String? code;
  @override
  String toString() => message;
}

class VoiceAdmissionCloseResult {
  const VoiceAdmissionCloseResult({
    required this.channelId,
    required this.revision,
    required this.revokedLeases,
  });

  final String channelId;
  final int revision;
  final int revokedLeases;
}

class ApiClient {
  ApiClient({http.Client? client}) : _transport = client ?? http.Client() {
    _client = TracingHttpClient(_transport);
  }
  @visibleForTesting
  static const MacOsOptions macOsSessionOptions = MacOsOptions(
    accountName: 'ru.boohtacord.boohtacordDesktop.session.v3',
    usesDataProtectionKeychain: false,
  );
  static const _serverKey = 'server_url';
  static const _cookieKey = 'boohtacord_session_cookie';
  final http.Client _transport;
  late final http.Client _client;
  bool _hadRealtimeConnection = false;

  Future<void> submitClientSpans(List<int> body) async {
    final response = await _transport.post(
      _uri('/telemetry/traces'),
      headers: {
        ...await _headers(),
        'content-type': 'application/x-protobuf',
        'x-client-platform': Platform.operatingSystem,
      },
      body: body,
    );
    if (response.statusCode != 202) {
      throw StateError('Telemetry export failed');
    }
  }
  void Function()? onUnauthorized;
  // Keep macOS on the legacy Keychain without sharing entitlements: the
  // Data Protection Keychain returns errSecMissingEntitlement for ad-hoc
  // builds. This versioned service isolates new sessions from prior items
  // that have blocked SecItemCopyMatching during startup.
  final FlutterSecureStorage _storage = Platform.isMacOS
      ? const FlutterSecureStorage(mOptions: macOsSessionOptions)
      : const FlutterSecureStorage();
  String baseUrl = 'https://v.bootybay.ru/api/v1';
  bool get realtimeEnabled => true;

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

  Map<String, String> _publicHeaders({String accept = 'application/json'}) {
    final server = Uri.parse(baseUrl);
    return {
      'accept': accept,
      'origin': '${server.scheme}://${server.authority}',
    };
  }

  Future<Map<String, String>> _headers({
    bool jsonBody = false,
    String accept = 'application/json',
  }) async {
    final cookie = await _storage.read(key: _cookieKey);
    return {
      ..._publicHeaders(accept: accept),
      if (jsonBody) 'content-type': 'application/json',
      'cookie': ?cookie,
    };
  }

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('$baseUrl$path').replace(queryParameters: query);

  Uri _avatarUri(String value) {
    final base = Uri.parse(baseUrl);
    final resolved = base.resolveUri(Uri.parse(value));
    final expectedPrefix = '${base.path}/members/';
    if (resolved.scheme != 'https' ||
        resolved.scheme != base.scheme ||
        resolved.host != base.host ||
        resolved.port != base.port ||
        !resolved.path.startsWith(expectedPrefix) ||
        !resolved.path.endsWith('/avatar')) {
      throw const ApiFailure('Сервер вернул недопустимый адрес аватара.');
    }
    return resolved;
  }

  Future<dynamic> _checked(
    http.Response response, {
    bool reportUnauthorized = true,
  }) async {
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
    if (response.statusCode == 401) {
      await _storage.delete(key: _cookieKey);
      if (reportUnauthorized) onUnauthorized?.call();
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

  Future<SessionUser?> currentSession() async {
    final response = await _client.get(
      _uri('/auth/session'),
      headers: await _headers(),
    );
    if (response.statusCode == 401) {
      await _storage.delete(key: _cookieKey);
      return null;
    }
    final data = await _checked(response) as Map<String, dynamic>;
    if (data['authenticated'] == false) return null;
    return SessionUser.fromJson(data);
  }

  Future<bool> maintenanceActive() async {
    final data = await _checked(
      await _client.get(_uri('/maintenance'), headers: _publicHeaders()),
    );
    if (data is! Map<String, dynamic> || data['active'] is! bool) {
      throw const ApiFailure('Сервер вернул некорректный статус обновления.');
    }
    return data['active'] as bool;
  }

  Future<void> reportScreenShareMetrics(Map<String, Object> report) async {
    await _checked(
      await _client.post(
        _uri('/voice/screen-metrics'),
        headers: await _headers(jsonBody: true),
        body: jsonEncode(report),
      ),
    );
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
        reportUnauthorized: false,
      );
    }
    await _checked(
      await _client.post(
        _uri('/auth/login'),
        headers: await _headers(jsonBody: true),
        body: body,
      ),
      reportUnauthorized: false,
    );
  }

  Future<void> logout() async {
    await _checked(
      await _client.post(_uri('/auth/logout'), headers: await _headers()),
    );
    await _storage.delete(key: _cookieKey);
  }

  Future<OwnProfile> ownProfile() async {
    final data = await _checked(
      await _client.get(_uri('/me'), headers: await _headers()),
    ) as Map<String, dynamic>;
    return OwnProfile.fromJson(data);
  }

  Future<Uint8List> avatarBytes(String avatarUrl) async {
    final response = await _client.get(
      _avatarUri(avatarUrl),
      headers: await _headers(accept: 'image/png'),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.bodyBytes;
    }
    await _checked(response);
    throw const ApiFailure('Не удалось загрузить аватар.');
  }

  Future<OwnProfile> updateOwnProfile(String displayName) async {
    final data = await _checked(
      await _client.patch(
        _uri('/me'),
        headers: await _headers(jsonBody: true),
        body: jsonEncode({'display_name': displayName}),
      ),
    ) as Map<String, dynamic>;
    return OwnProfile.fromJson(data);
  }

  Future<void> uploadOwnAvatar(Uint8List bytes, String contentType) async {
    await _checked(
      await _client.put(
        _uri('/me/avatar'),
        headers: {
          ...await _headers(accept: 'application/json'),
          'content-type': contentType,
        },
        body: bytes,
      ),
    );
  }

  Future<void> deleteOwnAvatar() async {
    await _checked(
      await _client.delete(_uri('/me/avatar'), headers: await _headers()),
    );
  }

  Future<void> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    await _checked(
      await _client.post(
        _uri('/me/password'),
        headers: await _headers(jsonBody: true),
        body: jsonEncode({
          'current_password': currentPassword,
          'new_password': newPassword,
        }),
      ),
    );
  }

  Future<void> completePasswordReset(String token, String password) async {
    late final http.Response response;
    try {
      response = await _client.post(
        _uri('/auth/password-reset/complete'),
        headers: await _headers(jsonBody: true),
        body: jsonEncode({'token': token, 'password': password}),
      );
    } catch (_) {
      throw const ApiFailure('Нет связи с сервером. Повторите попытку.');
    }
    if (response.statusCode == 204) {
      await _checked(response, reportUnauthorized: false);
      return;
    }
    if (response.statusCode == 400) {
      throw const ApiFailure(
        'Ссылка недействительна или срок её действия истёк. Попросите администратора выдать новую ссылку.',
        status: 400,
      );
    }
    if (response.statusCode == 429) {
      throw const ApiFailure(
        'Слишком много попыток. Подождите и повторите.',
        status: 429,
      );
    }
    throw ApiFailure(
      'Не удалось изменить пароль (${response.statusCode}). Повторите попытку.',
      status: response.statusCode,
    );
  }

  Future<ChannelTopology> topology() async {
    final data = await _checked(
      await _client.get(_uri('/channels'), headers: await _headers()),
    ) as Map<String, dynamic>;
    return ChannelTopology.fromJson(data);
  }

  Future<List<VoiceRoomRoster>> voiceParticipants() async {
    final data = await _checked(
      await _client.get(
        _uri('/voice/participants'),
        headers: {...await _headers(), 'cache-control': 'no-store'},
      ),
    );
    if (data is! Map<String, dynamic> || data['channels'] is! List) {
      throw const ApiFailure('Некорректный состав голосовых каналов.');
    }
    final rosters = (data['channels'] as List)
        .map((value) => VoiceRoomRoster.fromJson(value as Map<String, dynamic>))
        .toList(growable: false);
    if (rosters.map((item) => item.channelId).toSet().length !=
        rosters.length) {
      throw const ApiFailure('Сервер вернул повторный голосовой канал.');
    }
    return rosters;
  }

  Future<http.StreamedResponse> voiceRosterEvents() async {
    final request = http.Request('GET', _uri('/voice/rosters/events'));
    request.headers.addAll(await _headers(accept: 'text/event-stream'));
    final response = await _client.send(request);
    if (response.statusCode != 200) {
      await response.stream.drain<void>();
      throw ApiFailure(
        'Нет связи со списком голосовых каналов.',
        status: response.statusCode,
      );
    }
    return response;
  }

  Future<void> createCategory(String name) async {
    final normalized = name.trim();
    if (normalized.isEmpty || normalized.runes.length > 80) {
      throw const ApiFailure('Введите имя категории до 80 символов.');
    }
    await _checked(
      await _client.post(
        _uri('/admin/categories'),
        headers: await _headers(jsonBody: true),
        body: jsonEncode({'name': name}),
      ),
    );
  }

  Future<void> createChannel({
    required String categoryId,
    required String name,
    required ChannelKind kind,
  }) async {
    final normalized = name.trim();
    if (categoryId.isEmpty ||
        normalized.isEmpty ||
        normalized.runes.length > 80) {
      throw const ApiFailure('Введите имя канала до 80 символов.');
    }
    await _checked(
      await _client.post(
        _uri('/admin/categories/${Uri.encodeComponent(categoryId)}/channels'),
        headers: await _headers(jsonBody: true),
        body: jsonEncode({
          'name': name,
          'kind': kind == ChannelKind.text ? 'TEXT' : 'VOICE',
        }),
      ),
    );
  }

  Future<void> renameCategory({
    required String categoryId,
    required String name,
    required int expectedRevision,
  }) async {
    _validateAdminName(name, 'категории');
    if (categoryId.isEmpty || expectedRevision < 1) {
      throw const ApiFailure('Обновите список категорий и повторите действие.');
    }
    await _checked(
      await _client.patch(
        _uri('/admin/categories/${Uri.encodeComponent(categoryId)}'),
        headers: await _headers(jsonBody: true),
        body: jsonEncode({'name': name, 'expected_revision': expectedRevision}),
      ),
    );
  }

  Future<void> deleteEmptyCategory({
    required String categoryId,
    required int expectedRevision,
  }) async {
    if (categoryId.isEmpty || expectedRevision < 1) {
      throw const ApiFailure('Обновите список категорий и повторите действие.');
    }
    await _checked(
      await _client.delete(
        _uri('/admin/categories/${Uri.encodeComponent(categoryId)}', {
          'expected_revision': '$expectedRevision',
        }),
        headers: await _headers(),
      ),
    );
  }

  Future<void> renameChannel({
    required String channelId,
    required String name,
    required int expectedRevision,
  }) async {
    _validateAdminName(name, 'канала');
    if (channelId.isEmpty || expectedRevision < 1) {
      throw const ApiFailure('Обновите список каналов и повторите действие.');
    }
    await _checked(
      await _client.patch(
        _uri('/admin/channels/${Uri.encodeComponent(channelId)}'),
        headers: await _headers(jsonBody: true),
        body: jsonEncode({'name': name, 'expected_revision': expectedRevision}),
      ),
    );
  }

  Future<void> reorderCategories({
    required List<String> categoryIds,
    required int expectedRevision,
  }) async {
    _validateOrderedIds(categoryIds, expectedRevision);
    await _checked(
      await _client.put(
        _uri('/admin/categories/order'),
        headers: await _headers(jsonBody: true),
        body: jsonEncode({
          'expected_revision': expectedRevision,
          'ids': categoryIds,
        }),
      ),
    );
  }

  Future<void> reorderChannels({
    required String categoryId,
    required List<String> channelIds,
    required int expectedRevision,
  }) async {
    if (categoryId.isEmpty) {
      throw const ApiFailure('Обновите список каналов и повторите действие.');
    }
    _validateOrderedIds(channelIds, expectedRevision);
    await _checked(
      await _client.put(
        _uri(
          '/admin/categories/${Uri.encodeComponent(categoryId)}/channels/order',
        ),
        headers: await _headers(jsonBody: true),
        body: jsonEncode({
          'expected_revision': expectedRevision,
          'ids': channelIds,
        }),
      ),
    );
  }

  Future<void> moveChannel({
    required String channelId,
    required String categoryId,
    required int expectedRevision,
  }) async {
    if (channelId.isEmpty || categoryId.isEmpty || expectedRevision < 1) {
      throw const ApiFailure('Обновите список и повторите перенос канала.');
    }
    await _checked(
      await _client.patch(
        _uri('/admin/channels/${Uri.encodeComponent(channelId)}/category'),
        headers: await _headers(jsonBody: true),
        body: jsonEncode({
          'category_id': categoryId,
          'expected_revision': expectedRevision,
        }),
      ),
    );
  }

  Future<void> archiveTextChannel({
    required String channelId,
    required int expectedRevision,
  }) async {
    if (channelId.isEmpty || expectedRevision < 1) {
      throw const ApiFailure('Обновите список каналов и повторите архивацию.');
    }
    await _checked(
      await _client.delete(
        _uri('/admin/channels/${Uri.encodeComponent(channelId)}'),
        headers: await _headers(jsonBody: true),
        body: jsonEncode({
          'expected_revision': expectedRevision,
          'confirm_archive': true,
        }),
      ),
    );
  }

  Future<VoiceAdmissionCloseResult> closeVoiceAdmission({
    required String channelId,
    required int expectedRevision,
  }) async {
    if (channelId.isEmpty || expectedRevision < 1) {
      throw const ApiFailure(
        'Обновите список голосовых каналов и повторите действие.',
      );
    }
    final data = await _checked(
      await _client.post(
        _uri(
          '/admin/voice-channels/${Uri.encodeComponent(channelId)}/close-admission',
        ),
        headers: await _headers(jsonBody: true),
        body: jsonEncode({'expected_revision': expectedRevision}),
      ),
    ) as Map<String, dynamic>;
    final returnedId = data['id'];
    final revision = data['revision'];
    final revokedLeases = data['revoked_leases'];
    if (returnedId != channelId ||
        revision is! int ||
        revision < 1 ||
        revokedLeases is! int ||
        revokedLeases < 0) {
      throw const ApiFailure(
        'Сервер вернул некорректное состояние закрытия канала.',
      );
    }
    return VoiceAdmissionCloseResult(
      channelId: channelId,
      revision: revision,
      revokedLeases: revokedLeases,
    );
  }

  void _validateOrderedIds(List<String> ids, int expectedRevision) {
    if (ids.isEmpty ||
        ids.any((id) => id.isEmpty) ||
        ids.toSet().length != ids.length ||
        expectedRevision < 1) {
      throw const ApiFailure('Обновите список и повторите изменение порядка.');
    }
  }

  void _validateAdminName(String name, String item) {
    if (name.trim().isEmpty || name.runes.length > 80) {
      throw ApiFailure('Введите имя $item до 80 символов.');
    }
  }

  Future<void> advanceTextChannelReadCursor(
    String channelId,
    String messageId,
  ) async {
    await _checked(
      await _client.put(
        _uri('/channels/$channelId/read-cursor'),
        headers: await _headers(jsonBody: true),
        body: jsonEncode({'message_id': messageId}),
      ),
    );
  }

  Future<AdminAuditPage> listAdminAudit({
    String? before,
    int limit = 100,
  }) async {
    if (limit < 1 ||
        limit > 100 ||
        (before != null && (before.isEmpty || before.length > 512))) {
      throw const ApiFailure('Некорректный курсор аудита.');
    }
    final data = await _checked(
      await _client.get(
        _uri('/admin/audit', {'limit': '$limit', 'before': ?before}),
        headers: await _headers(),
      ),
    ) as Map<String, dynamic>;
    final rawEvents = data['events'];
    final cursor = data['next_cursor'];
    if (rawEvents is! List ||
        (cursor != null &&
            (cursor is! String || cursor.isEmpty || cursor.length > 512))) {
      throw const ApiFailure('Сервер вернул некорректный список аудита.');
    }
    return AdminAuditPage(
      events: rawEvents
          .map(
            (value) => AdminAuditEvent.fromJson(value as Map<String, dynamic>),
          )
          .toList(growable: false),
      nextCursor: cursor as String?,
    );
  }

  Future<List<AdminScreenSample>> listAdminScreenMetrics() async {
    final data = await _checked(
      await _client.get(
        _uri('/admin/screen-metrics'),
        headers: {...await _headers(), 'cache-control': 'no-store'},
      ),
    );
    if (data is! Map<String, dynamic> || data['samples'] is! List) {
      throw const ApiFailure('Сервер вернул некорректные показатели медиа.');
    }
    final samples = data['samples'] as List;
    if (samples.length > 16) {
      throw const ApiFailure('Сервер вернул некорректные показатели медиа.');
    }
    try {
      return samples
          .map(
            (value) =>
                AdminScreenSample.fromJson(value as Map<String, dynamic>),
          )
          .toList(growable: false);
    } on Object {
      throw const ApiFailure('Сервер вернул некорректные показатели медиа.');
    }
  }

  Future<AdminAccountPage> listAdminAccounts({
    String? cursor,
    int limit = 100,
  }) async {
    if (limit < 1 ||
        limit > 100 ||
        (cursor != null && (cursor.isEmpty || cursor.length > 512))) {
      throw const ApiFailure('Некорректный курсор участников.');
    }
    final data = await _checked(
      await _client.get(
        _uri('/admin/accounts', {'limit': '$limit', 'cursor': ?cursor}),
        headers: await _headers(),
      ),
    ) as Map<String, dynamic>;
    final rawAccounts = data['accounts'];
    final nextCursor = data['next_cursor'];
    if (rawAccounts is! List ||
        (nextCursor != null &&
            (nextCursor is! String ||
                nextCursor.isEmpty ||
                nextCursor.length > 512))) {
      throw const ApiFailure('Сервер вернул некорректный список участников.');
    }
    return AdminAccountPage(
      accounts: rawAccounts
          .map((value) => AdminAccount.fromJson(value as Map<String, dynamic>))
          .toList(growable: false),
      nextCursor: nextCursor as String?,
    );
  }

  Future<void> updateAdminAccount({
    required String accountId,
    required String role,
    required bool blocked,
  }) async {
    if (accountId.isEmpty || (role != 'MEMBER' && role != 'ADMINISTRATOR')) {
      throw const ApiFailure('Некорректные роль или участник.');
    }
    await _checked(
      await _client.patch(
        _uri('/admin/accounts/${Uri.encodeComponent(accountId)}'),
        headers: await _headers(jsonBody: true),
        body: jsonEncode({'role': role, 'blocked': blocked}),
      ),
    );
  }

  Future<AdminPasswordResetLink> createAdminPasswordResetLink(
    String accountId,
  ) async {
    if (accountId.isEmpty) {
      throw const ApiFailure('Выберите участника для сброса пароля.');
    }
    final data = await _checked(
      await _client.post(
        _uri('/admin/password-reset-links'),
        headers: await _headers(jsonBody: true),
        body: jsonEncode({'account_id': accountId}),
      ),
    ) as Map<String, dynamic>;
    final url = data['url'];
    final expiresAt = data['expires_at'];
    if (url is! String || url.isEmpty || expiresAt is! String) {
      throw const ApiFailure(
        'Сервер вернул некорректную ссылку сброса пароля.',
      );
    }
    return AdminPasswordResetLink(
      url: url,
      expiresAt: DateTime.parse(expiresAt).toLocal(),
    );
  }

  Future<int> kickAdminVoiceParticipant(String accountId) async {
    if (accountId.isEmpty) {
      throw const ApiFailure('Выберите участника для отключения от голоса.');
    }
    final data = await _checked(
      await _client.post(
        _uri('/admin/accounts/${Uri.encodeComponent(accountId)}/voice-kick'),
        headers: await _headers(),
      ),
    ) as Map<String, dynamic>;
    final revokedLeases = data['revoked_leases'];
    if (revokedLeases is! int || revokedLeases < 0) {
      throw const ApiFailure(
        'Сервер вернул некорректный результат отключения.',
      );
    }
    return revokedLeases;
  }

  Future<List<ChatMessage>> messages(String channelId) async {
    return (await messagePage(channelId)).messages;
  }

  Future<ChatMessagePage> messagePage(
    String channelId, {
    String? before,
    String? at,
  }) async {
    if (before != null && at != null) {
      throw const ApiFailure('Выберите один курсор истории.');
    }
    final data = await _checked(
      await _client.get(
        _uri('/channels/$channelId/messages', {
          'before': ?before,
          'at': ?at,
          if (at != null) 'limit': '20',
        }),
        headers: await _headers(),
      ),
    ) as Map<String, dynamic>;
    final values = (data['messages'] as List<dynamic>)
        .map((value) => ChatMessage.fromJson(value as Map<String, dynamic>))
        .toList();
    values.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return ChatMessagePage(
      messages: values,
      nextCursor: data['next_cursor'] as String?,
    );
  }

  Future<List<GuildMember>> members() async {
    final result = <GuildMember>[];
    String? cursor;
    do {
      final data = await _checked(
        await _client.get(
          _uri('/members', {'limit': '100', 'cursor': ?cursor}),
          headers: await _headers(),
        ),
      ) as Map<String, dynamic>;
      result.addAll(
        (data['members'] as List<dynamic>).map(
          (value) => GuildMember.fromJson(value as Map<String, dynamic>),
        ),
      );
      cursor = data['next_cursor'] as String?;
    } while (cursor != null);
    return result;
  }

  Future<GuildMember> memberProfile(String accountId) async {
    if (accountId.isEmpty) {
      throw const ApiFailure('Не выбран участник гильдии.');
    }
    final data = await _checked(
      await _client.get(
        _uri('/members/${Uri.encodeComponent(accountId)}'),
        headers: await _headers(),
      ),
    );
    if (data is! Map<String, dynamic>) {
      throw const ApiFailure('Сервер вернул некорректные данные участника.');
    }
    return GuildMember.fromJson(data);
  }

  Future<List<DirectConversation>> directMessages() async {
    final data = await _checked(
      await _client.get(_uri('/direct-messages'), headers: await _headers()),
    ) as Map<String, dynamic>;
    return (data['direct_messages'] as List<dynamic>)
        .map(
          (value) => DirectConversation.fromJson(value as Map<String, dynamic>),
        )
        .toList(growable: false);
  }

  Future<List<DirectCandidate>> directMessageCandidates() async {
    final result = <DirectCandidate>[];
    String? after;
    do {
      final data = await _checked(
        await _client.get(
          _uri('/direct-message-candidates', {'limit': '100', 'after': ?after}),
          headers: await _headers(),
        ),
      ) as Map<String, dynamic>;
      result.addAll(
        (data['candidates'] as List<dynamic>).map(
          (value) => DirectCandidate.fromJson(value as Map<String, dynamic>),
        ),
      );
      after = data['next_after'] as String?;
    } while (after != null);
    return result;
  }

  Future<String> openDirectMessage(String participantId) async {
    final data = await _checked(
      await _client.post(
        _uri('/direct-messages'),
        headers: await _headers(jsonBody: true),
        body: jsonEncode({'participant_id': participantId}),
      ),
    ) as Map<String, dynamic>;
    return data['id'] as String;
  }

  Future<List<DirectChatMessage>> directMessageHistory(String id) async {
    return (await directMessageHistoryPage(id)).messages;
  }

  Future<DirectChatMessagePage> directMessageHistoryPage(
    String id, {
    String? before,
    String? at,
  }) async {
    if (before != null && at != null) {
      throw const ApiFailure('Выберите один курсор истории.');
    }
    final data = await _checked(
      await _client.get(
        _uri('/direct-messages/$id/messages', {
          'before': ?before,
          'at': ?at,
          if (at != null) 'limit': '20',
        }),
        headers: await _headers(),
      ),
    ) as Map<String, dynamic>;
    final values = (data['messages'] as List<dynamic>)
        .map(
          (value) => DirectChatMessage.fromJson(value as Map<String, dynamic>),
        )
        .toList();
    values.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return DirectChatMessagePage(
      messages: values,
      nextCursor: data['next_cursor'] as String?,
    );
  }

  Future<SearchMessagePage> searchMessages(
    String query, {
    String? channelId,
    String? directMessageId,
    String? before,
    int limit = 20,
  }) async {
    if (channelId != null && directMessageId != null) {
      throw const ApiFailure('Выберите один фильтр беседы.');
    }
    final data = await _checked(
      await _client.get(
        _uri('/search/messages', {
          'query': query,
          'channel_id': ?channelId,
          'direct_message_id': ?directMessageId,
          'before': ?before,
          'limit': '$limit',
        }),
        headers: await _headers(),
      ),
    ) as Map<String, dynamic>;
    final rawMessages = data['messages'];
    if (rawMessages is! List) {
      throw const ApiFailure('Сервер вернул некорректные результаты поиска.');
    }
    final cursor = data['next_cursor'];
    if (cursor != null &&
        (cursor is! String || cursor.isEmpty || cursor.length > 512)) {
      throw const ApiFailure('Сервер вернул некорректные результаты поиска.');
    }
    return SearchMessagePage(
      messages: rawMessages
          .map((value) => SearchMessage.fromJson(value as Map<String, dynamic>))
          .toList(growable: false),
      nextCursor: cursor as String?,
    );
  }

  Future<MessageAttachment> uploadChannelAttachment(
    String channelId,
    String fileName,
    Uint8List bytes, {
    void Function(int sent, int total)? onProgress,
  }) => _uploadMessageAttachment(
    '/channels/$channelId/attachments',
    fileName,
    bytes,
    onProgress: onProgress,
  );

  Future<MessageAttachment> uploadDirectMessageAttachment(
    String directMessageId,
    String fileName,
    Uint8List bytes, {
    void Function(int sent, int total)? onProgress,
  }) => _uploadMessageAttachment(
    '/direct-messages/$directMessageId/attachments',
    fileName,
    bytes,
    onProgress: onProgress,
  );

  Future<MessageAttachment> _uploadMessageAttachment(
    String path,
    String fileName,
    Uint8List bytes, {
    void Function(int sent, int total)? onProgress,
  }) async {
    if (fileName.isEmpty || bytes.length > 25000000) {
      throw const ApiFailure('Файл должен быть не больше 25 МБ.');
    }
    final request = _ProgressMultipartRequest('POST', _uri(path), onProgress);
    request.headers.addAll(await _headers());
    request.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: fileName),
    );
    final response = await http.Response.fromStream(
      await _client.send(request),
    );
    final data = await _checked(response) as Map<String, dynamic>;
    return MessageAttachment.fromJson(data);
  }

  Future<Uint8List> messageAttachmentBytes(
    String parentPath,
    String attachmentId, {
    bool preview = false,
  }) async {
    final response = await _client.get(
      _uri(
        '$parentPath/attachments/${Uri.encodeComponent(attachmentId)}${preview ? '/preview' : ''}',
      ),
      headers: await _headers(accept: preview ? 'image/*' : '*/*'),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.bodyBytes;
    }
    await _checked(response);
    throw const ApiFailure('Не удалось загрузить вложение.');
  }

  Future<DirectChatMessage> sendDirectMessage(
    String id,
    String clientMessageId,
    String body, {
    String? replyToId,
    List<String> mentionUserIds = const [],
    List<String> attachmentIds = const [],
  }) async {
    final data = await _checked(
      await _client.post(
        _uri('/direct-messages/$id/messages'),
        headers: await _headers(jsonBody: true),
        body: jsonEncode({
          'client_message_id': clientMessageId,
          'body': body,
          'reply_to_id': ?replyToId,
          if (mentionUserIds.isNotEmpty) 'mention_user_ids': mentionUserIds,
          if (attachmentIds.isNotEmpty) 'attachment_ids': attachmentIds,
        }),
      ),
    ) as Map<String, dynamic>;
    return DirectChatMessage.fromJson(data);
  }

  Future<DirectChatMessage> editDirectMessage(
    String directMessageId,
    String messageId,
    String body,
    int expectedRevision, {
    List<String> mentionUserIds = const [],
  }) async {
    final data = await _checked(
      await _client.patch(
        _uri('/direct-messages/$directMessageId/messages/$messageId'),
        headers: await _headers(jsonBody: true),
        body: jsonEncode({
          'body': body,
          'expected_revision': expectedRevision,
          'mention_user_ids': mentionUserIds,
        }),
      ),
    ) as Map<String, dynamic>;
    return DirectChatMessage.fromJson(data);
  }

  Future<void> deleteDirectMessage(
    String directMessageId,
    String messageId,
  ) async {
    await _checked(
      await _client.delete(
        _uri('/direct-messages/$directMessageId/messages/$messageId'),
        headers: await _headers(),
      ),
    );
  }

  Future<void> advanceDirectMessageReadCursor(
    String directMessageId,
    String messageId,
  ) async {
    await _checked(
      await _client.put(
        _uri('/direct-messages/$directMessageId/read-cursor'),
        headers: await _headers(jsonBody: true),
        body: jsonEncode({'message_id': messageId}),
      ),
    );
  }

  Future<WebSocket> openRealtime() async {
    return ClientTelemetry.trace(
      _hadRealtimeConnection ? 'realtime.reconnect' : 'realtime.connect',
      () async {
        final httpUri = Uri.parse(baseUrl);
        final realtimeUri = httpUri.replace(
          scheme: 'wss',
          path: '${httpUri.path}/realtime',
          query: null,
        );
        final headers = await _headers();
        headers.addAll(ClientTelemetry.currentTraceHeaders());
        final socket = await WebSocket.connect(
          realtimeUri.toString(),
          headers: headers,
        );
        _hadRealtimeConnection = true;
        return socket;
      },
    );
  }

  Future<ChatMessage> sendMessage(
    String channelId,
    String clientMessageId,
    String body, {
    String? replyToId,
    List<String> mentionUserIds = const [],
    List<String> attachmentIds = const [],
  }) async {
    final response = await _client.post(
      _uri('/channels/$channelId/messages'),
      headers: await _headers(jsonBody: true),
      body: jsonEncode({
        'client_message_id': clientMessageId,
        'body': body,
        'reply_to_id': ?replyToId,
        if (mentionUserIds.isNotEmpty) 'mention_user_ids': mentionUserIds,
        if (attachmentIds.isNotEmpty) 'attachment_ids': attachmentIds,
      }),
    );
    return ChatMessage.fromJson(
      await _checked(response) as Map<String, dynamic>,
    );
  }

  Future<ChatMessage> editMessage(
    String channelId,
    String messageId,
    String body,
    int expectedRevision, {
    List<String> mentionUserIds = const [],
  }) async {
    final data = await _checked(
      await _client.patch(
        _uri('/channels/$channelId/messages/$messageId'),
        headers: await _headers(jsonBody: true),
        body: jsonEncode({
          'body': body,
          'expected_revision': expectedRevision,
          'mention_user_ids': mentionUserIds,
        }),
      ),
    ) as Map<String, dynamic>;
    return ChatMessage.fromJson(data);
  }

  Future<void> deleteMessage(String channelId, String messageId) async {
    await _checked(
      await _client.delete(
        _uri('/channels/$channelId/messages/$messageId'),
        headers: await _headers(),
      ),
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

class _ProgressMultipartRequest extends http.MultipartRequest {
  _ProgressMultipartRequest(super.method, super.url, this.onProgress);

  final void Function(int sent, int total)? onProgress;

  @override
  http.ByteStream finalize() {
    final total = contentLength;
    var sent = 0;
    return http.ByteStream(
      super.finalize().map((chunk) {
        sent += chunk.length;
        onProgress?.call(sent, total);
        return chunk;
      }),
    );
  }
}
