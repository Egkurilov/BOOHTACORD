import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Local voice levels belong to the signed-in account, not to a LiveKit track.
class VoiceVolumePreferences {
  VoiceVolumePreferences(this._storage, this._accountId);

  final SharedPreferences? _storage;
  final String _accountId;
  final Map<String, int> _participantCache = {};
  final Map<String, int> _screenCache = {};
  Future<void> _pendingWrite = Future<void>.value();

  static Future<VoiceVolumePreferences> open(String accountId) async {
    try {
      return VoiceVolumePreferences(
        await SharedPreferences.getInstance(),
        accountId,
      );
    } catch (_) {
      return VoiceVolumePreferences(null, accountId);
    }
  }

  bool get persistent => _storage != null;

  static int normalize(num percent) =>
      percent.isFinite ? percent.round().clamp(0, 200) : 100;

  String _key(String remoteAccountId) =>
      'voice-volume:v1:$_accountId:$remoteAccountId';

  int participant(String remoteAccountId) => _participantCache.putIfAbsent(
    remoteAccountId,
    () {
      try {
        final decoded = jsonDecode(
          _storage?.getString(_key(remoteAccountId)) ?? '{}',
        );
        if (decoded is Map<String, dynamic> && decoded['participant'] is num) {
          return normalize(decoded['participant'] as num);
        }
      } catch (_) {}
      return 100;
    },
  );

  int screen(String remoteAccountId) => _screenCache.putIfAbsent(
    remoteAccountId,
    () => _readLevel(remoteAccountId, 'screen'),
  );

  int _readLevel(String remoteAccountId, String field) {
    try {
      final decoded = jsonDecode(
        _storage?.getString(_key(remoteAccountId)) ?? '{}',
      );
      if (decoded is Map<String, dynamic> && decoded[field] is num) {
        return normalize(decoded[field] as num);
      }
    } catch (_) {}
    return 100;
  }

  Future<void> setParticipant(String remoteAccountId, num percent) =>
      _set(remoteAccountId, 'participant', percent);

  Future<void> setScreen(String remoteAccountId, num percent) =>
      _set(remoteAccountId, 'screen', percent);

  Future<void> _set(String remoteAccountId, String field, num percent) {
    final level = normalize(percent);
    final key = _key(remoteAccountId);
    if (field == 'participant') {
      _participantCache[remoteAccountId] = level;
    } else {
      _screenCache[remoteAccountId] = level;
    }
    Future<void> write() async {
      Map<String, dynamic> stored = {};
      try {
        final decoded = jsonDecode(_storage?.getString(key) ?? '{}');
        if (decoded is Map<String, dynamic>) stored = decoded;
      } catch (_) {}
      final saved = await _storage?.setString(
        key,
        jsonEncode({...stored, field: level}),
      );
      if (saved != true) {
        throw StateError('Voice volume preference was not saved.');
      }
    }

    final next = _pendingWrite.then((_) => write(), onError: (_) => write());
    _pendingWrite = next;
    return next;
  }
}
