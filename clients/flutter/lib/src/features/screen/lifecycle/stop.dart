import 'controller.dart';

extension ScreenShareStop on ScreenShareController {
  Future<void> stopScreenShare() {
    final previous = closing;
    if (previous != null) return previous;
    final operation = closeCapture(++revision);
    closing = operation;
    return operation.whenComplete(() {
      if (identical(closing, operation)) closing = null;
    });
  }

  Future<void> closeCapture(int expected) async {
    final room = readRoom();
    final pending = starting;
    final wasIdle = phase == ScreenSharePhase.idle;
    activeTrack = null;
    capturedContentVisibility.track(null);
    stopSampling();
    phase = ScreenSharePhase.stopping;
    changed();
    try {
      await pending;
      if (room != null && !wasIdle) await driver.stop(room);
      await driver.disableBackground();
      if (expected != revision) return;
      phase = ScreenSharePhase.idle;
      error = null;
    } catch (cause) {
      if (expected != revision) return;
      phase = ScreenSharePhase.error;
      error =
          'Не удалось остановить демонстрацию: ${screenShareFailureDetail(cause)}';
    }
    changed();
  }
}
