import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/services/audio_preferences.dart';
import 'package:boohtacord_desktop/src/services/native_noise_suppression.dart';

void main() {
  test('legacy preferences migrate without changing independent AEC/AGC', () {
    expect(
      AudioProcessingPreferences.fromJson({
        'noiseSuppression': false,
        'autoGainControl': false,
      }).noiseSuppressionMode,
      NoiseSuppressionMode.off,
    );
    expect(
      AudioProcessingPreferences.fromJson({'noiseSuppression': true})
          .noiseSuppressionMode,
      NoiseSuppressionMode.browser,
    );
    expect(
      AudioProcessingPreferences.fromJson({'noiseSuppressionMode': 'unknown'})
          .noiseSuppressionMode,
      NoiseSuppressionMode.browser,
    );
    expect(
      AudioProcessingPreferences.fromJson({
        'noiseSuppressionMode': 'rnnoise',
        'echoCancellation': false,
      }).echoCancellation,
      isFalse,
    );
  });
  test('RNNoise waits for actual native frames and preserves request during fallback', () async {
    var frames = 0;
    final native = NativeNoiseSuppression(
      invoke: (method, args) async => {
        'supported': true,
        'effectiveEngine': frames == 0 ? 'unknown' : 'rnnoise',
        'processedFrames': frames,
      },
    );
    expect(
      await native.prepare(NoiseSuppressionMode.rnnoise),
      NoiseSuppressionMode.rnnoise,
    );
    expect(native.state.effectiveMode, 'unknown');
    frames = 3;
    await native.refresh();
    expect(native.state.effectiveMode, 'rnnoise');
    await native.useFallback('unsupported-audio-format');
    expect(native.state.requestedMode, NoiseSuppressionMode.rnnoise);
    expect(native.state.effectiveMode, 'browser');
  });
  test('missing native support falls back without losing preference', () async {
    final native = NativeNoiseSuppression(
      invoke: (method, args) async => {
        'supported': false,
        'failureReason': 'unsupported',
      },
    );
    expect(
      await native.prepare(NoiseSuppressionMode.rnnoise),
      NoiseSuppressionMode.browser,
    );
    await native.useFallback('unsupported', unsupported: true);
    expect(native.state.requestedMode, NoiseSuppressionMode.rnnoise);
    expect(native.state.status, 'unsupported');
  });
  test('one owner serializes processing and microphone operations', () async {
    final native = NativeNoiseSuppression(invoke: (method, args) async => {});
    final events = <int>[];
    final completer = Completer<void>();
    final first = native.run(() async {
      await completer.future;
      events.add(1);
    });
    final second = native.run(() async {
      events.add(2);
    });
    expect(events, isEmpty);
    completer.complete();
    await Future.wait([first, second]);
    expect(events, [1, 2]);
  });
  test('cancel invalidates delayed native state', () async {
    final completer = Completer<Object?>();
    final native = NativeNoiseSuppression(
      invoke: (method, args) => completer.future,
    );
    final preparing = native.prepare(NoiseSuppressionMode.rnnoise);
    native.cancel();
    completer.complete({
      'supported': true,
      'effectiveEngine': 'rnnoise',
      'processedFrames': 4,
    });
    await preparing;
    expect(native.state.status, 'idle');
    expect(native.state.effectiveMode, 'unknown');
  });
  test(
    'fallback remains unknown until capture browser constraints commit',
    () async {
      final native = NativeNoiseSuppression(
        invoke: (method, args) async => {'supported': true},
      );
      await native.prepare(NoiseSuppressionMode.rnnoise);
      await native.useFallback(
        'unsupported-audio-format',
        captureApplied: false,
      );
      expect(native.state.effectiveMode, 'unknown');
      native.confirmFallback('unsupported-audio-format');
      expect(native.state.effectiveMode, 'browser');
    },
  );
  test('cancel rejects delayed fallback state from a closed room', () async {
    final pending = Completer<Object?>();
    final native = NativeNoiseSuppression(
      invoke: (method, args) async {
        if (args?['engine'] == 'browser') return pending.future;
        return {'supported': true};
      },
    );
    await native.prepare(NoiseSuppressionMode.rnnoise);
    final fallback = native.useFallback('hook-error');
    native.cancel();
    pending.complete({'effectiveEngine': 'browser'});
    await fallback;
    expect(native.state.effectiveMode, 'unknown');
    expect(native.state.status, 'idle');
  });
}
