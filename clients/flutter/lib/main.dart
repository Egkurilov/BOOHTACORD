import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:window_manager/window_manager.dart';

import 'src/app.dart';
import 'src/services/api_client.dart';
import 'src/services/third_party_audio_licenses.dart';
import 'src/services/client_telemetry.dart';
import 'src/telemetry/traced_app_state.dart';
import 'src/features/updates/api.dart';
import 'src/features/updates/controller.dart';
import 'src/features/updates/identity.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerThirdPartyAudioLicenses();
  if (Platform.isAndroid) {
    await rtc.WebRTC.initialize(
      options: {'androidUseHardwareNoiseSuppression': false},
    );
  }
  if (Platform.isMacOS || Platform.isWindows) {
    await windowManager.ensureInitialized();
    const options = WindowOptions(
      size: Size(1440, 900),
      minimumSize: Size(1024, 680),
      center: true,
      backgroundColor: Color(0xFF0E1117),
      title: 'BOOHTACORD',
      titleBarStyle: TitleBarStyle.hidden,
      windowButtonVisibility: true,
    );
    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }
  final api = ApiClient();
  await ClientTelemetry.initialize(api.submitClientSpans);
  final state = TracedAppState(api);
  final updates = UpdateController(
    api: UpdateApi(baseUrl: () => api.baseUrl),
    identity: await NativeUpdateIdentity.load(),
  );
  runApp(BoohtacordApp(state: state, updates: updates));
  await state.initialize();
  updates.start();
}
