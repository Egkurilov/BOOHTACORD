import 'package:boohtacord_desktop/src/screens/voice_screen_selection_rail.dart';
import 'package:boohtacord_desktop/src/screens/voice_viewer_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('screen selection rail includes local and remote streams', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    String? selectedIdentity = 'peer-1';
    late StateSetter setState;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, update) {
            setState = update;
            return Scaffold(
              body: VoiceScreenSelectionRail(
                choices: [
                  VoiceScreenChoice(
                    identity: null,
                    label: 'Ваш экран',
                    selected: selectedIdentity == null,
                    isLocal: true,
                    avatarIdentity: 'account-1',
                    avatarLabel: 'Евгений',
                  ),
                  VoiceScreenChoice(
                    identity: 'peer-1',
                    label: 'Алиса',
                    selected: selectedIdentity == 'peer-1',
                    accountId: 'account-2',
                    avatarLabel: 'Алиса',
                    hasAudio: true,
                  ),
                ],
                onSelected: (identity) =>
                    setState(() => selectedIdentity = identity),
              ),
            );
          },
        ),
      ),
    );

    expect(find.text('Ваш экран'), findsOneWidget);
    expect(find.text('Алиса'), findsOneWidget);
    expect(find.text('Вы смотрите'), findsOneWidget);
    expect(find.text('Нажмите, чтобы смотреть'), findsOneWidget);
    expect(find.text('Е'), findsOneWidget);
    expect(find.text('А'), findsOneWidget);
    expect(find.byIcon(Icons.volume_up_outlined), findsOneWidget);
    expect(find.byIcon(Icons.volume_off_outlined), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('voice-screen-choice-peer-1'))),
      const Size(184, 64),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('Алиса')),
      matchesSemantics(
        label: 'Алиса',
        hint: 'Открыть демонстрацию экрана. Звуковая дорожка есть',
        isButton: true,
        isSelected: true,
        hasSelectedState: true,
        hasTapAction: true,
      ),
    );

    await tester.tap(find.text('Ваш экран'));
    await tester.pump();
    expect(selectedIdentity, isNull);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Ваш экран')),
      matchesSemantics(
        label: 'Ваш экран',
        hint:
            'Предпросмотр собственного экрана без звука. Звуковой дорожки нет',
        isButton: true,
        isSelected: true,
        hasSelectedState: true,
        hasTapAction: true,
      ),
    );

    await tester.tap(find.text('Алиса'));
    await tester.pump();
    expect(selectedIdentity, 'peer-1');

    expect(find.byTooltip('Ваш экран, предпросмотр без звука'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('places the selectable stream rail below the video stage', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 700);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: VoiceViewerLayout(
            stage: ColoredBox(
              key: ValueKey('video-stage'),
              color: Colors.black,
            ),
            diagnostics: SizedBox(
              key: ValueKey('viewer-diagnostics'),
              height: 40,
            ),
            streamRail: SizedBox(key: ValueKey('stream-rail'), height: 76),
            participants: SizedBox(
              key: ValueKey('participant-strip'),
              height: 92,
            ),
          ),
        ),
      ),
    );

    final stage = tester.getRect(find.byKey(const ValueKey('video-stage')));
    final diagnostics = tester.getRect(
      find.byKey(const ValueKey('viewer-diagnostics')),
    );
    final rail = tester.getRect(find.byKey(const ValueKey('stream-rail')));
    final participants = tester.getRect(
      find.byKey(const ValueKey('participant-strip')),
    );
    expect(stage.bottom, lessThanOrEqualTo(diagnostics.top));
    expect(diagnostics.bottom, lessThanOrEqualTo(rail.top));
    expect(rail.bottom, lessThanOrEqualTo(participants.top));
    expect(tester.takeException(), isNull);
  });
}
