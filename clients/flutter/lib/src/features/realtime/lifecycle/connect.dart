import 'controller.dart';

extension RealtimeConnection on RealtimeController {
  Future<void> connect() async {
    final active = admission();
    if (!api.realtimeEnabled || !active() || socket != null || connecting) {
      return;
    }
    connecting = true;
    try {
      final opened = await api.openRealtime();
      if (!active()) {
        await opened.close();
        return;
      }
      socket = opened;
      attempt = 0;
      subscription = opened.listen(
        (raw) {
          if (active() && identical(socket, opened)) receive(raw);
        },
        onDone: () {
          if (active() && identical(socket, opened)) handleClosed();
        },
        onError: (_) {
          if (active() && identical(socket, opened)) handleClosed();
        },
        cancelOnError: true,
      );
    } catch (_) {
      if (active()) scheduleRetry();
    } finally {
      if (active()) connecting = false;
    }
  }
}
