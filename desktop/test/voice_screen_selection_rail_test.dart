import 'package:boohtacord_desktop/src/screens/voice_screen_selection_rail.dart';
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
                  ),
                  VoiceScreenChoice(
                    identity: 'peer-1',
                    label: 'Алиса',
                    selected: selectedIdentity == 'peer-1',
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
    expect(
      tester.getSemantics(find.bySemanticsLabel('Алиса')),
      matchesSemantics(
        label: 'Алиса',
        hint: 'Открыть демонстрацию экрана',
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
        hint: 'Предпросмотр собственного экрана без звука',
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
}
