import 'package:boohtacord_desktop/src/screens/voice_screen_stage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('desktop screen stage is full-bleed with the web source label', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 700);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: VoiceScreenStage(
            video: ColoredBox(
              key: ValueKey('stage-video-surface'),
              color: Colors.blue,
            ),
            publisherName: 'Алиса',
            avatarName: 'Алиса',
          ),
        ),
      ),
    );

    final stage = tester.getRect(
      find.byKey(const ValueKey('voice-screen-stage')),
    );
    final video = tester.getRect(
      find.byKey(const ValueKey('stage-video-surface')),
    );
    final label = tester.getRect(
      find.byKey(const ValueKey('voice-screen-stage-label')),
    );
    expect(stage.size, const Size(900, 700));
    expect(video, stage);
    expect(label.left, stage.left + 16);
    expect(label.top, stage.top + 16);
    expect(label.height, 40);
    expect(find.text('Экран Алиса'), findsOneWidget);
    expect(find.text('ЭФИР'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('voice-screen-stage-avatar')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<ClipRRect>(
            find.byKey(const ValueKey('voice-screen-stage-clip')),
          )
          .borderRadius,
      BorderRadius.circular(12),
    );
  });

  testWidgets('compact local stage uses the web inset and hides its avatar', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: VoiceScreenStage(
            video: ColoredBox(
              key: ValueKey('stage-video-surface'),
              color: Colors.blue,
            ),
            publisherName: 'ваш экран',
            avatarName: 'Евгений',
            isLocal: true,
          ),
        ),
      ),
    );

    final stage = tester.getRect(
      find.byKey(const ValueKey('voice-screen-stage')),
    );
    final label = tester.getRect(
      find.byKey(const ValueKey('voice-screen-stage-label')),
    );
    expect(stage.size, const Size(390, 844));
    expect(label.left, stage.left + 8);
    expect(label.top, stage.top + 8);
    expect(label.height, 28);
    expect(find.text('Ваш экран'), findsOneWidget);
    expect(find.text('ЭФИР'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('voice-screen-stage-avatar')),
      findsNothing,
    );
  });

  testWidgets('long compact publisher label stays clear of viewer controls', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: VoiceScreenStage(
            video: ColoredBox(
              key: ValueKey('stage-video-surface'),
              color: Colors.blue,
            ),
            publisherName: 'A very long publisher account name',
            avatarName: 'A very long publisher account name',
            reservedTrailingWidth: 172,
          ),
        ),
      ),
    );

    final stage = tester.getRect(
      find.byKey(const ValueKey('voice-screen-stage')),
    );
    final label = tester.getRect(
      find.byKey(const ValueKey('voice-screen-stage-label')),
    );
    expect(label.right, lessThanOrEqualTo(stage.right - 172));
    expect(
      find.text('Экран A very long publisher account name'),
      findsOneWidget,
    );
  });
}
