import 'package:flutter_test/flutter_test.dart';

import 'package:boohtacord_desktop/src/features/voice/screen_viewer/audio_toggle.dart';

void main() {
  test('toggling normal stream audio changes only mute state', () async {
    final calls = <String>[];

    await toggleScreenAudioWithCallbacks(
      volume: 65,
      muted: false,
      setVolume: (value) async => calls.add('volume:$value'),
      setMuted: (value) async => calls.add('muted:$value'),
    );

    expect(calls, ['muted:true']);
  });

  test(
    'zero gain restores normal volume without toggling an unmuted stream',
    () async {
      final calls = <String>[];

      await toggleScreenAudioWithCallbacks(
        volume: 0,
        muted: false,
        setVolume: (value) async => calls.add('volume:$value'),
        setMuted: (value) async => calls.add('muted:$value'),
      );

      expect(calls, ['volume:100']);
    },
  );

  test('zero gain restores volume before clearing an explicit mute', () async {
    final calls = <String>[];

    await toggleScreenAudioWithCallbacks(
      volume: 0,
      muted: true,
      setVolume: (value) async => calls.add('volume:$value'),
      setMuted: (value) async => calls.add('muted:$value'),
    );

    expect(calls, ['volume:100', 'muted:false']);
  });
}
