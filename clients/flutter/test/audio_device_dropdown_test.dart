import 'package:boohtacord_desktop/src/screens/workspace_ui/audio_device_dropdown/component.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart' show MediaDevice;

void main() {
  testWidgets('truncated device label keeps its full text in semantics', (
    tester,
  ) async {
    const fullLabel =
        'USB Headset — Bluetooth Stereo Hands-Free Audio Device 4f91';
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WorkspaceAudioDeviceDropdown(
            label: 'Микрофон',
            devices: const [
              MediaDevice('device-4f91', fullLabel, 'audioinput', null),
            ],
            selectedId: 'device-4f91',
            switching: false,
            emptyLabel: 'Нет доступных устройств',
            onChanged: (_) {},
          ),
        ),
      ),
    );

    final selected = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const ValueKey('audio-device-control-Микрофон')),
        matching: find.text(fullLabel),
      ).first,
    );
    expect(selected.overflow, TextOverflow.ellipsis);
    expect(selected.semanticsLabel, fullLabel);
    expect(tester.takeException(), isNull);
  });
}
