import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../voice/microphone/shortcut.dart';
import 'processing.dart';
import 'microphone.dart';
part 'storage.dart';
class AudioPreferences {
  AudioPreferences(this._storage, this._accountId);

  final SharedPreferences? _storage;
  final String _accountId;
  Future<void> _pendingWrite = Future<void>.value();
  MicrophoneSettings microphone = const MicrophoneSettings();
  AudioProcessingPreferences processing = const AudioProcessingPreferences();
  String? inputDeviceId;
  String? outputDeviceId;
  String activationMode = 'VAD';
  int? pttKeyId;
  String? pttKeyLabel;
  VoiceShortcutBinding? microphoneShortcut;
  VoiceShortcutBinding? deafenShortcut;

  bool get persistent => _storage != null;

  static Future<AudioPreferences> open(String accountId) async {
    SharedPreferences? storage;
    try {
      storage = await SharedPreferences.getInstance();
    } catch (_) {}
    final preferences = AudioPreferences(storage, accountId);
    preferences._load();
    return preferences;
  }

  String get _key => 'audio-preferences:v1:$_accountId';

  Future<void> setProcessing(AudioProcessingPreferences value) {
    if (_storage == null) return _unavailable();
    processing = value;
    return _save();
  }

  Future<void> setInputDevice(String? id) {
    if (_storage == null) return _unavailable();
    inputDeviceId = id;
    return _save();
  }

  Future<void> setOutputDevice(String? id) {
    if (_storage == null) return _unavailable();
    outputDeviceId = id;
    return _save();
  }

  Future<void> setActivationMode(String value) {
    if (_storage == null) return _unavailable();
    activationMode = value == 'PTT' ? 'PTT' : 'VAD';
    return _save();
  }

  Future<void> setPttKey(int? keyId, String? label) {
    if (_storage == null) return _unavailable();
    pttKeyId = keyId;
    pttKeyLabel = label;
    return _save();
  }

  Future<void> setMicrophoneShortcut(VoiceShortcutBinding? value) {
    if (_storage == null) return _unavailable();
    microphoneShortcut = value;
    return _save();
  }

  Future<void> setDeafenShortcut(VoiceShortcutBinding? value) {
    if (_storage == null) return _unavailable();
    deafenShortcut = value;
    return _save();
  }

  Future<void> setMicrophoneSettings(MicrophoneSettings value) {
    if (_storage == null) return _unavailable();
    microphone = MicrophoneSettings.fromJson(value.toJson());
    return _save();
  }
}
