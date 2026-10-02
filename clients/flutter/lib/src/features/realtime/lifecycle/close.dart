import 'controller.dart';

extension RealtimeCleanup on RealtimeController {
  Future<void> close() async {
    generation++;
    retry?.cancel();
    retry = null;
    final previousSubscription = subscription;
    final previousSocket = socket;
    subscription = null;
    socket = null;
    connected = false;
    connecting = false;
    checkingSession = false;
    eventIds.clear();
    if (!disposed) {
      invalidatePresence();
      changed();
    }
    try {
      await previousSubscription?.cancel();
    } finally {
      await previousSocket?.close();
    }
  }
}
