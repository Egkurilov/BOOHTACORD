import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../features/voice/microphone/shortcut.dart';

enum NoiseSuppressionMode { off, browser, rnnoise }

class AudioProcessingPreferences {
  const AudioProcessingPreferences({
    this.autoGainControl = true,
    this.echoCancellation = true,
    NoiseSuppressionMode? noiseSuppressionMode,
    bool? noiseSuppression,
  }) : noiseSuppressionMode =
           noiseSuppressionMode ??
           (noiseSuppression == false
               ? NoiseSuppressionMode.off
               : NoiseSuppressionMode.browser);

  final bool autoGainControl;
  final bool echoCancellation;
  final NoiseSuppressionMode noiseSuppressionMode;
  bool get noiseSuppression =>
      noiseSuppressionMode == NoiseSuppressionMode.browser;

  AudioProcessingPreferences copyWith({
    bool? autoGainControl,
    bool? echoCancellation,
    bool? noiseSuppression,
    NoiseSuppressionMode? noiseSuppressionMode,
  }) => AudioProcessingPreferences(
    autoGainControl: autoGainControl ?? this.autoGainControl,
    echoCancellation: echoCancellation ?? this.echoCancellation,
    noiseSuppressionMode:
        noiseSuppressionMode ??
        (noiseSuppression == null
            ? this.noiseSuppressionMode
            : noiseSuppression
            ? NoiseSuppressionMode.browser
            : NoiseSuppressionMode.off),
  );

  Map<String, Object> toJson() => {
    'autoGainControl': autoGainControl,
    'echoCancellation': echoCancellation,
    'noiseSuppressionMode': noiseSuppressionMode.name,
  };

  factory AudioProcessingPreferences.fromJson(Object? value) {
    if (value is! Map<String, dynamic>) {
      return const AudioProcessingPreferences();
    }
    return AudioProcessingPreferences(
      autoGainControl: value['autoGainControl'] is bool
          ? value['autoGainControl'] as bool
          : true,
      echoCancellation: value['echoCancellation'] is bool
          ? value['echoCancellation'] as bool
          : true,
      noiseSuppressionMode: NoiseSuppressionMode.values
          .where((mode) => mode.name == value['noiseSuppressionMode'])
          .firstOrNull,
      noiseSuppression: value['noiseSuppression'] is bool
          ? value['noiseSuppression'] as bool
          : true,
    );
  }
}

class AudioPreferences {
  AudioPreferences(this._storage, this._accountId);

  final SharedPreferences? _storage;
  final String _accountId;
  Future<void> _pendingWrite = Future<void>.value();
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

  void _load() {
    try {
      final raw = _storage?.getString(_key);
      if (raw == null) return;
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return;
      processing = AudioProcessingPreferences.fromJson(decoded['processing']);
      inputDeviceId = decoded['inputDeviceId'] as String?;
      outputDeviceId = decoded['outputDeviceId'] as String?;
      activationMode = decoded['activationMode'] == 'PTT' ? 'PTT' : 'VAD';
      pttKeyId = decoded['pttKeyId'] is int ? decoded['pttKeyId'] as int : null;
      pttKeyLabel = decoded['pttKeyLabel'] as String?;
      microphoneShortcut = _shortcut(decoded['microphoneShortcut']);
      deafenShortcut = _shortcut(decoded['deafenShortcut']);
    } catch (_) {}
  }

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

  VoiceShortcutBinding? _shortcut(Object? value) {
    try { return value == null ? null : VoiceShortcutBinding.fromJson(value); } catch (_) { return null; }
  }

  Future<void> _unavailable() => Future<void>.error(
    StateError('Audio preferences storage is unavailable.'),
  );

  Future<void> _save() {
    if (_storage == null) {
      return Future<void>.error(
        StateError('Audio preferences storage is unavailable.'),
      );
    }
    Future<void> write() async {
      final result = await _storage.setString(
        _key,
        jsonEncode({
          'processing': processing.toJson(),
          'inputDeviceId': inputDeviceId,
          'outputDeviceId': outputDeviceId,
          'activationMode': activationMode,
          'pttKeyId': pttKeyId,
          'pttKeyLabel': pttKeyLabel,
          'microphoneShortcut': microphoneShortcut?.toJson(),
          'deafenShortcut': deafenShortcut?.toJson(),
        }),
      );
      if (result == false) {
        throw StateError('Audio preferences were not saved.');
      }
    }

    final next = _pendingWrite.then((_) => write());
    _pendingWrite = next.catchError((_) {});
    return next;
  }
}
