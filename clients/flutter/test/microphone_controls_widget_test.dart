import 'package:boohtacord_desktop/src/features/audio/preferences/microphone.dart';
import 'package:boohtacord_desktop/src/features/audio/microphone_controls/native.dart';
import 'package:boohtacord_desktop/src/widgets/microphone_controls/control.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
void main() {
  testWidgets('AGC disables manual gain and PTT disables sensitivity', (tester) async {
    final runtime = NativeMicrophoneControls(invoke: (_, _) async => {'status': 'active'});
    Widget widget(bool sensitivity) => MaterialApp(home: Scaffold(body: MicrophoneControl(
      settings: const MicrophoneSettings(), runtime: runtime,
      onChanged: ({double? vadThresholdDb, double? microphoneGainPercent}) async {},
      sensitivity: sensitivity, vad: false, agc: true,
    )));
    await tester.pumpWidget(widget(false));
    expect(tester.widget<Slider>(find.byType(Slider)).onChanged, isNull);
    expect(find.textContaining('Управляется автоматически'), findsOneWidget);
    await tester.pumpWidget(widget(true));
    expect(tester.widget<Slider>(find.byType(Slider)).onChanged, isNull);
    expect(find.textContaining('В режиме PTT'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    runtime.dispose();
  });
}
