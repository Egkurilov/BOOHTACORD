import 'package:boohtacord_desktop/src/widgets/voice_microphone_unavailable_notice.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('explains listener fallback and allows a microphone retry', (
    tester,
  ) async {
    var retryCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VoiceMicrophoneUnavailableNotice(onRetry: () => retryCount++),
        ),
      ),
    );

    expect(find.text('Микрофон недоступен'), findsOneWidget);
    expect(find.textContaining('подключены как слушатель'), findsOneWidget);
    expect(find.textContaining('разрешение'), findsOneWidget);
    expect(find.byTooltip('Повторить включение микрофона'), findsOneWidget);

    await tester.tap(find.byTooltip('Повторить включение микрофона'));
    expect(retryCount, 1);
  });

  testWidgets('does not bypass push-to-talk for a microphone retry', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: VoiceMicrophoneUnavailableNotice()),
      ),
    );

    expect(
      find.textContaining('Удерживайте назначенную PTT-клавишу'),
      findsOneWidget,
    );
    expect(find.text('Повторить'), findsNothing);
  });
}
