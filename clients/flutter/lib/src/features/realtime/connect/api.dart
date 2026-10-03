import 'dart:io';

import '../../../core/http/transport.dart';
import '../../../services/client_telemetry.dart';

class RealtimeConnectApi {
  RealtimeConnectApi(this.transport);
  final ApiTransport transport;
  bool _hadRealtimeConnection = false;

  Future<WebSocket> openRealtime() async {
    return ClientTelemetry.trace(
      _hadRealtimeConnection ? 'realtime.reconnect' : 'realtime.connect',
      () async {
        final httpUri = Uri.parse(transport.session.baseUrl);
        final realtimeUri = httpUri.replace(
          scheme: 'wss',
          path: '${httpUri.path}/realtime',
          queryParameters: const {'capabilities': 'role_permissions_v1'},
        );
        final headers = await transport.headers();
        headers.addAll(ClientTelemetry.currentTraceHeaders());
        final socket = await WebSocket.connect(
          realtimeUri.toString(),
          headers: headers,
        );
        try {
          transport.ensureCurrent();
        } catch (_) {
          await socket.close();
          rethrow;
        }
        _hadRealtimeConnection = true;
        return socket;
      },
    );
  }
}
