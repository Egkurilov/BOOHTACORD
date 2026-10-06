import 'controller.dart';
import '../../telemetry/action_scope/action.dart';
import '../../../services/client_telemetry.dart';

extension RealtimeConnection on RealtimeController {
  Future<void> connect() async {
    final active = admission();
    if (!api.realtimeEnabled || !active() || socket != null || connecting) {
      return;
    }
    connecting = true;
    handshake?.finish('superseded');
    final flow = ActionScope(
      hadConnection ? 'realtime.reconnect' : 'realtime.connect',
      api.transport.session.telemetry,
      enabled: ClientTelemetry.enabled,
    );
    handshake = flow;
    flow.step('connect');
    try {
      final opened = await flow.run(api.openRealtime);
      if (!active()) {
        flow.finish('cancelled', reason: 'generation_changed');
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
      flow.finish('failed', reason: 'network');
      if (active()) scheduleRetry();
    } finally {
      if (active()) connecting = false;
    }
  }
}
