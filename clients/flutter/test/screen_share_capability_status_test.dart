import 'package:boohtacord_desktop/src/screens/voice_screen_stage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('local screen shows video publication, absent screen audio, and voice continuity', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: VoiceScreenStage(
          video: ColoredBox(color: Colors.black),
          publisherName: 'Вы',
          avatarName: 'Вы',
          isLocal: true,
        ),
      ),
    ));

    expect(find.text('Видео опубликовано · звук экрана не публикуется'), findsOneWidget);
    expect(find.text('Голосовой канал остаётся активен.'), findsOneWidget);
  });

  testWidgets('remote screen makes no claim about sender track state', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: VoiceScreenStage(
          video: ColoredBox(color: Colors.black),
          publisherName: 'Участник',
          avatarName: 'Участник',
        ),
      ),
    ));

    expect(find.text('Видео опубликовано · звук экрана не публикуется'), findsNothing);
    expect(find.text('Голосовой канал остаётся активен.'), findsNothing);
  });
}
