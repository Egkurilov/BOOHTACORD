import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/features/voice/audio_diagnostics/model.dart';
import 'package:boohtacord_desktop/src/widgets/voice_audio_diagnostics/control.dart';
void main() {
  testWidgets('explains codec evidence limits and preserves unknown RED', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SingleChildScrollView(
      child: VoiceAudioDiagnosticsControl(connected: true,
        diagnostics: VoiceAudioDiagnostics('baseline-128-v1', 128000, {}, [
          {'direction': 'sender', 'codec': 'opus', 'red': null},
        ])),
    ))));
    await tester.tap(find.text('Диагностика качества голоса'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Opus в статистике не исключает RED'), findsOneWidget);
    expect(find.textContaining('RED неизвестно'), findsOneWidget);
  });
}
