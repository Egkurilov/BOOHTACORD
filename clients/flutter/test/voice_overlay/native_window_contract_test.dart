import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Windows voice overlay remains click-through and non-activating', () {
    final source = [
      'windows/runner/voice_overlay/window_lifecycle/lifecycle.cpp',
      'windows/runner/voice_overlay/window_events/handler.cpp',
    ].map((path) => File(path).readAsStringSync()).join('\n');
    expect(source, contains('WS_EX_TOPMOST'));
    expect(source, contains('WS_EX_LAYERED'));
    expect(source, contains('WS_EX_NOACTIVATE'));
    expect(source, contains('WS_EX_TRANSPARENT'));
    expect(source, contains('return MA_NOACTIVATE'));
    expect(source, contains('return HTTRANSPARENT'));
    expect(source, contains('nullptr, nullptr, instance, this'));
  });

  test(
    'native overlay path owns no voice connection or microphone capture',
    () {
      final files = [
        File('windows/runner/voice_overlay/window_lifecycle/lifecycle.cpp'),
        File('windows/runner/voice_overlay/bridge/channel.cpp'),
      ];
      final source = files.map((file) => file.readAsStringSync()).join('\n');
      expect(source, isNot(contains('FlutterViewController')));
      expect(source, isNot(contains('Room::')));
      expect(source, isNot(contains('getUserMedia')));
      expect(source, isNot(contains('RECORD_AUDIO')));
    },
  );

  test('runner keeps a single Flutter view controller for the overlay', () {
    final source = File('windows/runner/flutter_window.cpp').readAsStringSync();
    expect(
      RegExp(r'make_unique<flutter::FlutterViewController>').allMatches(source),
      hasLength(1),
    );
  });
}
