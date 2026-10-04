import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'model.dart';
part 'storage.dart';
part 'write.dart';
class VoiceVolumePreferences {
  VoiceVolumePreferences(this._storage, this._accountId, {String origin = ''})
      : _origin = deploymentOrigin(origin) { _load(); }
  final SharedPreferences? _storage;
  final String _accountId, _origin;
  bool belongsTo(String accountId, String origin) => _accountId == accountId && _origin == deploymentOrigin(origin);
  final _values = <String, VoiceLevels>{};
  String status = 'success';
  Timer? _timer;
  String? _payload;
  Completer<void>? _batch;
  Future<void> _tail = Future<void>.value();
  bool get persistent => status == 'success';
  static int normalize(num value) => normalizeLevel(value);
  static Future<VoiceVolumePreferences> open(String accountId, {required String origin}) async {
    try { return VoiceVolumePreferences(await SharedPreferences.getInstance(), accountId, origin: origin); }
    catch (_) { return VoiceVolumePreferences(null, accountId, origin: origin); }
  }
  int participant(String id) => (_values[id] ?? const VoiceLevels()).participant;
  int screen(String id) => (_values[id] ?? const VoiceLevels()).screen;
  Future<void> setParticipant(String id, num percent) {
    _values[id] = VoiceLevels(normalize(percent), screen(id));
    return _schedule();
  }
  Future<void> setScreen(String id, num percent) {
    _values[id] = VoiceLevels(participant(id), normalize(percent));
    return _schedule();
  }
  Future<void> reset() {
    _values.clear();
    _schedule();
    return flush();
  }
  Future<void> flush() => _flush();
  String get key => 'voice-volume:v2:${Uri.encodeComponent(_origin)}:${Uri.encodeComponent(_accountId)}';
}
