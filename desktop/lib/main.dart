import 'dart:io';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'src/app.dart';
import 'src/services/api_client.dart';
import 'src/services/client_telemetry.dart';
import 'src/telemetry/traced_app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isMacOS || Platform.isWindows) {
    await windowManager.ensureInitialized();
    const options = WindowOptions(
      size: Size(1440, 900),
      minimumSize: Size(1024, 680),
      center: true,
      backgroundColor: Color(0xFF0E1117),
      title: 'BOOHTACORD',
    );
    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }
  final api = ApiClient();
  await ClientTelemetry.initialize(api.submitClientSpans);
  final state = TracedAppState(api);
  runApp(BoohtacordApp(state: state));
  await state.initialize();
}
