import 'package:boohtacord_desktop/src/widgets/voice_stream_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows an accessible stream icon without a thumbnail', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: VoiceStreamIndicator())),
    );
    expect(find.byIcon(Icons.desktop_windows_outlined), findsOneWidget);
    expect(find.bySemanticsLabel('Показывает экран'), findsOneWidget);
  });
}
