import 'package:boohtacord_desktop/src/features/audio/preferences/microphone.dart';
import 'package:boohtacord_desktop/src/features/audio/microphone_controls/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('configuration is local, hot and not confirmed without capture frames', () async {
    final calls = <String>[];
    final controls = NativeMicrophoneControls(invoke: (method, args) async {
      calls.add(method);
      expect(args?.containsKey('pcm'), false);
      if (calls.length <= 2) expect(args?['microphoneGainPercent'], 175.0);
      return {'status': 'initializing'};
    });
    await controls.configure(const MicrophoneSettings(microphoneGainPercent: 175), vad: true, agc: true);
    expect(controls.status, 'initializing');
    await controls.configure(const MicrophoneSettings(microphoneGainPercent: 175), vad: false, agc: false);
    expect(calls, ['setMicrophoneControls', 'setMicrophoneControls']);
    await controls.clear();
    expect(controls.levelDb, -90);
    controls.dispose();
  });
  test('missing native hook is explicitly unsupported', () async {
    final controls = NativeMicrophoneControls(invoke: (_, _) async => throw MissingPluginException());
    await controls.configure(const MicrophoneSettings(), vad: true, agc: true);
    expect(controls.status, 'unsupported');
    controls.dispose();
  });
  testWidgets(
    'disposing the default channel-backed runtime is safe under FakeAsync',
    (tester) async {
      NativeMicrophoneControls().dispose();
      await tester.pump();
    },
  );
}
