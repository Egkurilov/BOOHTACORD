import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../preferences/microphone.dart';
typedef MicrophoneInvoker = Future<Object?> Function(String, Map<String, Object>?);
class NativeMicrophoneControls extends ChangeNotifier {
  NativeMicrophoneControls({MicrophoneInvoker? invoke})
      : _invoke = invoke ?? ((method, args) => _channel.invokeMethod<Object?>(method, args));
  static const _channel = MethodChannel('FlutterWebRTC.Method');
  final MicrophoneInvoker _invoke;
  Future<void> _tail = Future.value();
  Timer? _timer;
  int _generation = 0;
  bool _disposed = false, _polling = false;
  String status = 'idle';
  double levelDb = -90;
  bool clipping = false, gateOpen = false;
  Future<void> configure(MicrophoneSettings settings, {required bool vad, required bool agc, bool enabled = true}) {
    final generation = _generation;
    final args = <String, Object>{...settings.toJson(), 'vad': vad, 'agc': agc, 'enabled': enabled};
    final next = _tail.then((_) async {
      if (enabled && (_disposed || generation != _generation)) return;
      try {
        final response = await _invoke('setMicrophoneControls', args).timeout(const Duration(milliseconds: 500));
        if (enabled) _update(response, generation);
      }
      catch (_) { if (generation == _generation && !_disposed) { status = 'unsupported'; notifyListeners(); } }
    });
    _tail = next.catchError((Object _) {});
    return next;
  }
  void _update(Object? raw, int generation) {
    if (generation != _generation || _disposed) return;
    final map = raw is Map ? raw : const {};
    final reported = map['status'];
    status = const ['initializing', 'active', 'unsupported', 'error'].contains(reported) ? reported as String : 'unsupported';
    final db = map['levelDb'];
    levelDb = db is num && db.isFinite ? db.toDouble().clamp(-90, 0) : -90;
    clipping = map['clipping'] == true; gateOpen = map['gateOpen'] == true;
    notifyListeners();
  }
  void monitor() {
    _timer?.cancel();
    final generation = _generation;
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (_polling || _disposed) return;
      _polling = true;
      unawaited(_invoke('getMicrophoneControlsState', null)
        .timeout(const Duration(milliseconds: 500))
        .then((value) => _update(value, generation))
        .catchError((Object _) { if (!_disposed && generation == _generation) { status = 'error'; notifyListeners(); } })
        .whenComplete(() => _polling = false));
    });
  }
  void pause() {
    _generation++; _timer?.cancel(); _timer = null;
    status = 'idle'; levelDb = -90; clipping = false; gateOpen = false;
    if (!_disposed) notifyListeners();
  }
  Future<void> clear() {
    pause();
    return configure(const MicrophoneSettings(), vad: false, agc: true, enabled: false);
  }
  @override
  void dispose() {
    unawaited(clear());
    _disposed = true;
    super.dispose();
  }
}
