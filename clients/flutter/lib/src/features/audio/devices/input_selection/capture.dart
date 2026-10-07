import 'package:livekit_client/livekit_client.dart';

import '../state.dart';

mixin AudioInputTrackCapture on AudioDeviceState {
  Future<void> switchInputTrack(
    LocalAudioTrack track,
    MediaDevice device,
    bool Function() current,
    void Function() markFallback,
  ) async {
    final previousOptions = track.currentOptions;
    await track.mute(stopOnMute: false);
    await nativeNoise.reset();
    try {
      await track.restartTrack(
        previousOptions.copyWith(deviceId: device.deviceId),
      );
    } catch (_) {
      if (!current()) {
        await track.stop();
        return;
      }
      try {
        await track.restartTrack(previousOptions);
        if (current() && !microphoneMutedIntent) {
          await track.unmute(stopOnMute: false);
        }
        if (!current()) {
          await track.stop();
          return;
        }
        if (microphoneMutedIntent) await track.mute(stopOnMute: false);
        markFallback();
      } catch (_) {
        microphoneMutedIntent = true;
        nativeNoise.failMuted('input-switch-failed');
      }
      rethrow;
    }
    if (!current()) {
      await track.stop();
      return;
    }
    if (!microphoneMutedIntent) await track.unmute(stopOnMute: false);
    if (!current()) {
      await track.stop();
      return;
    }
    if (microphoneMutedIntent) await track.mute(stopOnMute: false);
  }
}
