import 'package:boohtacord_desktop/src/screens/voice_screen_ended.dart';
import 'package:boohtacord_desktop/src/screens/voice_screen_selection_rail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('keeps ended stream explicit until the user chooses an action', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 900);
    addTearDown(tester.view.reset);
    String? selectedIdentity;
    var returnedToParticipants = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VoiceScreenEndedView(
            choices: const [
              VoiceScreenChoice(
                identity: null,
                label: 'Ваш экран',
                selected: false,
                isLocal: true,
                avatarIdentity: 'account-1',
              ),
              VoiceScreenChoice(
                identity: 'peer-2',
                label: 'Алиса',
                selected: false,
                accountId: 'account-2',
                hasAudio: true,
              ),
            ],
            participants: const SizedBox(height: 92),
            onScreenSelected: (identity) => selectedIdentity = identity,
            onReturnToParticipants: () => returnedToParticipants = true,
          ),
        ),
      ),
    );

    expect(
      find.text(
        'Демонстрация завершена. Выберите другую вручную или вернитесь к участникам.',
      ),
      findsOneWidget,
    );
    expect(find.text('Демонстрации в канале'), findsOneWidget);
    expect(
      find.text('Невыбранные демонстрации не воспроизводятся.'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('voice-screen-choice-peer-2')));
    await tester.pump();
    expect(selectedIdentity, 'peer-2');

    await tester.tap(find.text('К участникам'));
    await tester.pump();
    expect(returnedToParticipants, isTrue);
    expect(tester.takeException(), isNull);
  });
}
