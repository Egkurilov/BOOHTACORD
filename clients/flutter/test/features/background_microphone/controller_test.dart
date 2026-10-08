import 'package:boohtacord_desktop/src/features/voice/background_microphone/session.dart';
import 'package:boohtacord_desktop/src/features/voice/lifecycle/controller.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../voice_scope/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('background fresh unmute fails closed before native capture work', () async {
    final calls = <String>[];
    final foreground = MicrophoneForegroundSession(android: true, invoke: (method) async { calls.add(method); return false; });
    final harness = VoiceHarness(foreground: foreground); addTearDown(harness.dispose);
    harness.owner.room = harness.room;
    expect(await harness.owner.applyMicrophoneMuted(false), false);
    expect(harness.owner.microphoneMuted, true); expect(harness.owner.microphoneUnavailable, true);
    expect(harness.owner.audio.microphoneMutedIntent, true); expect(harness.owner.listenerOnly, true);
    expect(calls, ['canStart', 'stop']); expect(harness.created, 0);
  });
  test('explicit leave stops voice FGS and does not create another Room', () async {
    final calls = <String>[];
    final foreground = MicrophoneForegroundSession(android: true, invoke: (method) async { calls.add(method); return true; });
    final harness = VoiceHarness(foreground: foreground); addTearDown(harness.dispose);
    harness.owner.room = harness.room; harness.owner.voicePhase = VoicePhase.connected;
    await foreground.start(); await harness.owner.leaveVoice();
    expect(foreground.active, false); expect(calls, ['start', 'stop']);
    expect(harness.owner.room, isNull); expect(harness.created, 0);
  });
  test('native service loss preserves explicit muted listener state', () async {
    final foreground = MicrophoneForegroundSession(android: true, invoke: (_) async => true);
    final harness = VoiceHarness(foreground: foreground); addTearDown(harness.dispose);
    harness.owner.room = harness.room; harness.owner.voicePhase = VoicePhase.connected;
    foreground.onStopped?.call(); await harness.owner.microphoneTail;
    expect(harness.owner.microphoneMuted, true); expect(harness.owner.audio.microphoneMutedIntent, true);
    expect(harness.owner.listenerOnly, true); expect(harness.owner.voicePhase, VoicePhase.listener);
  });
  test('promotion denial disables SDK microphone before listener fallback', () async {
    final calls = <String>[];
    final foreground = MicrophoneForegroundSession(android: true, invoke: (method) async { calls.add(method); return method == 'canStart'; });
    final harness = VoiceHarness(foreground: foreground); addTearDown(harness.dispose);
    harness.owner.room = harness.room;
    final enabling = harness.owner.applyMicrophoneMuted(false);
    await harness.room.localParticipant.started.future;
    harness.room.localParticipant.capture.complete();
    expect(await enabling, false); expect(harness.room.localParticipant.enabled, [true, false]);
    expect(harness.owner.microphoneMuted, true); expect(calls, ['canStart', 'start', 'stop']);
    expect(harness.owner.audio.microphoneMutedIntent, true); expect(harness.owner.listenerOnly, true);
  });
  test('leave during SDK capture prevents late FGS and disables late microphone', () async {
    final calls = <String>[];
    final foreground = MicrophoneForegroundSession(android: true, invoke: (method) async { calls.add(method); return true; });
    final harness = VoiceHarness(foreground: foreground); addTearDown(harness.dispose);
    harness.owner.room = harness.room;
    final enabling = harness.owner.applyMicrophoneMuted(false);
    await harness.room.localParticipant.started.future;
    await harness.owner.leaveVoice(); harness.room.localParticipant.capture.complete();
    expect(await enabling, false); expect(calls, isNot(contains('start')));
    expect(harness.room.localParticipant.enabled, [true, false]);
  });
}
