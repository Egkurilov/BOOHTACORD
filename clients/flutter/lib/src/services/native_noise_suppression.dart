import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'audio_preferences.dart';
import 'native_noise_suppression_state.dart';
export 'native_noise_suppression_state.dart';

typedef NativeNoiseInvoker = Future<Object?> Function(
  String method,
  Map<String, Object?>? arguments,
);

/// PCM remains in the hook; Dart exchanges bounded aggregate state only.
class NativeNoiseSuppression extends ChangeNotifier {
  NativeNoiseSuppression({NativeNoiseInvoker? invoke})
    : _invoke = invoke ?? _defaultInvoke;
  static const _channel = MethodChannel('FlutterWebRTC.Method');
  static Future<Object?> _defaultInvoke(
    String method,
    Map<String, Object?>? arguments,
  ) => _channel.invokeMethod<Object?>(method, arguments);
  final NativeNoiseInvoker _invoke;
  Future<void> _tail = Future.value();
  int _queued = 0;
  int _generation = 0;
  bool _disposed = false, _fallback = false, _polling = false;
  Timer? _timer;
  NativeNoiseSuppressionState state = const NativeNoiseSuppressionState();
  Future<T> run<T>(Future<T> Function() operation) {
    final next = _queued++ == 0
        ? Future<T>.sync(operation)
        : _tail.catchError((_) {}).then((_) => operation());
    _tail = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next.whenComplete(() => _queued--);
  }

  Future<Object?> _call(String method, [Map<String, Object?>? arguments]) =>
      _invoke(method, arguments).timeout(const Duration(milliseconds: 350));
  void _update(NativeNoiseSuppressionState value) {
    if (!_disposed) {
      state = value;
      notifyListeners();
    }
  }

  Future<NoiseSuppressionMode> prepare(NoiseSuppressionMode mode) async {
    final generation = _generation;
    _fallback = false;
    _update(
      NativeNoiseSuppressionState(
        requestedMode: mode,
        status: mode == NoiseSuppressionMode.rnnoise ? 'initializing' : 'idle',
      ),
    );
    try {
      final raw = await _call('setNoiseSuppressionEngine', {
        'engine': mode.name,
      });
      if (_disposed || generation != _generation) {
        return NoiseSuppressionMode.browser;
      }
      final value = raw is Map ? raw : const {};
      if (mode == NoiseSuppressionMode.rnnoise && value['supported'] != true) {
        _update(
          NativeNoiseSuppressionState(
            requestedMode: mode,
            status: 'unsupported',
            failureReason: value['failureReason'] as String? ?? 'unsupported',
          ),
        );
        return NoiseSuppressionMode.browser;
      }
      _read(value);
      return mode;
    } catch (_) {
      if (!_disposed && generation == _generation) {
        _update(
          NativeNoiseSuppressionState(
            requestedMode: mode,
            status: mode == NoiseSuppressionMode.rnnoise
                ? 'unsupported'
                : 'idle',
            failureReason: 'unsupported',
          ),
        );
      }
      return mode == NoiseSuppressionMode.rnnoise
          ? NoiseSuppressionMode.browser
          : mode;
    }
  }

  void _read(Map value) {
    final frames = value['processedFrames'] is int
        ? value['processedFrames'] as int
        : 0;
    final effective = value['effectiveEngine'];
    final reason = value['failureReason'] as String?;
    final rnnoise = state.requestedMode == NoiseSuppressionMode.rnnoise;
    final active =
        effective == 'rnnoise' &&
        frames > 0 &&
        (reason == null || reason.isEmpty);
    _update(
      NativeNoiseSuppressionState(
        requestedMode: state.requestedMode,
        effectiveMode: rnnoise
            ? active
                  ? 'rnnoise'
                  : 'unknown'
            : effective == 'browser' || effective == 'off'
            ? effective as String
            : 'unknown',
        status: rnnoise
            ? active
                  ? 'active'
                  : 'initializing'
            : 'idle',
        failureReason: reason,
        processedFrames: frames,
        fallbackFrames: value['fallbackFrames'] is int
            ? value['fallbackFrames'] as int
            : 0,
        sampleRate: value['sampleRate'] as int?,
        channels: value['channels'] as int?,
      ),
    );
  }

  Future<void> refresh() async {
    if (_fallback || _disposed) return;
    final generation = _generation;
    final raw = await _call('getNoiseSuppressionState');
    if (generation == _generation && raw is Map) _read(raw);
  }

  Future<void> useFallback(
    String reason, {
    bool unsupported = false,
    bool captureApplied = true,
  }) async {
    final requested = state.requestedMode;
    final generation = _generation;
    _fallback = true;
    try {
      await _call('setNoiseSuppressionEngine', {'engine': 'browser'});
    } catch (_) {}
    if (generation != _generation || _disposed) return;
    _update(
      NativeNoiseSuppressionState(
        requestedMode: requested,
        effectiveMode: captureApplied ? 'browser' : 'unknown',
        status: captureApplied
            ? unsupported
                  ? 'unsupported'
                  : 'fallback'
            : 'initializing',
        failureReason: reason,
      ),
    );
  }

  void confirmFallback(String reason, {bool unsupported = false}) {
    _update(
      NativeNoiseSuppressionState(
        requestedMode: state.requestedMode,
        effectiveMode: 'browser',
        status: unsupported ? 'unsupported' : 'fallback',
        failureReason: reason,
      ),
    );
  }

  Future<void> reset() async {
    try {
      await _call('resetNoiseSuppression');
    } catch (_) {}
  }

  void failMuted(String reason) {
    _generation++;
    _timer?.cancel();
    _fallback = true;
    _update(
      NativeNoiseSuppressionState(
        requestedMode: state.requestedMode,
        status: 'error',
        failureReason: reason,
      ),
    );
  }

  void monitor(Future<void> Function(String reason) recover) {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (_polling ||
          _fallback ||
          state.requestedMode != NoiseSuppressionMode.rnnoise) {
        return;
      }
      _polling = true;
      final generation = _generation;
      unawaited(
        run(() async {
          if (generation != _generation || _disposed) return;
          try {
            await refresh();
            final reason = state.failureReason;
            if (reason != null &&
                reason.isNotEmpty &&
                reason != 'awaiting-audio' &&
                generation == _generation) {
              await recover(reason);
            }
          } catch (_) {
            if (generation == _generation) await recover('hook-error');
          }
        }).catchError((Object _) {}).whenComplete(() => _polling = false),
      );
    });
  }

  void cancel() {
    _generation++;
    _timer?.cancel();
    _timer = null;
    _fallback = false;
    _update(NativeNoiseSuppressionState(requestedMode: state.requestedMode));
    unawaited(
      _invoke('resetNoiseSuppression', null).catchError((Object _) => null),
    );
  }

  @override
  void dispose() {
    cancel();
    _disposed = true;
    super.dispose();
  }
}
