import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/widgets/voice_shortcuts/row.dart';
import 'package:boohtacord_desktop/src/widgets/voice_shortcuts/status.dart';
import 'package:boohtacord_desktop/src/widgets/voice_shortcuts/keyboard.dart';
import 'package:boohtacord_desktop/src/widgets/voice_shortcuts/availability.dart';

void main() {
  test('mobile discovery stays hidden until a foreground hardware event', () {
    final availability = ShortcutAvailability();
    expect(availability.enabled(mobile: true), isFalse);
    expect(availability.enabled(mobile: false), isTrue);
    availability.observeHardwareKey();
    expect(availability.enabled(mobile: true), isTrue);
    availability.setForeground(false, mobile: true);
    availability.observeHardwareKey();
    expect(availability.enabled(mobile: true), isFalse);
    expect(availability.hardwareKeyboard, isFalse);
    availability.setForeground(true, mobile: true);
    expect(availability.enabled(mobile: true), isFalse);
  });
  testWidgets(
    'capture row stays responsive and status is a visible live region',
    (tester) async {
      var assigns = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 280,
              child: VoiceShortcutRow(
                label: 'Микрофон',
                binding: null,
                capturing: true,
                onAssign: () => assigns++,
                onClear: () {},
                onCancel: () {},
              ),
            ),
            floatingActionButton: const VoiceShortcutStatus(
              message: 'Микрофон выключен.',
            ),
          ),
        ),
      );
      final mobileLabel = find.text('Микрофон · Не назначено');
      expect(
        tester.getTopLeft(find.byType(OutlinedButton)).dy,
        greaterThanOrEqualTo(tester.getBottomLeft(mobileLabel).dy),
      );
      expect(find.text('Нажмите сочетание…'), findsOneWidget);
      await tester.tap(find.byType(OutlinedButton));
      expect(assigns, 1);
      expect(find.text('Микрофон выключен.'), findsOneWidget);
      expect(
        tester
            .widget<Semantics>(
              find
                  .ancestor(
                    of: find.text('Микрофон выключен.'),
                    matching: find.byType(Semantics),
                  )
                  .first,
            )
            .properties
            .liveRegion,
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('desktop shortcut row places assignment controls on the right', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 300);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 800,
              child: VoiceShortcutRow(
                label: 'Микрофон',
                desktopLayout: true,
                binding: null,
                capturing: false,
                onAssign: () {},
                onClear: () {},
                onCancel: () {},
              ),
            ),
          ),
        ),
      ),
    );

    final label = find.textContaining('Микрофон');
    final assign = find.byType(OutlinedButton);
    expect(tester.getCenter(label).dy, closeTo(tester.getCenter(assign).dy, 1));
    expect(tester.getTopRight(assign).dx, greaterThan(560));
    expect(tester.takeException(), isNull);
  });
  testWidgets('editable and modal focus block shortcuts', (tester) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: TextField(focusNode: focus)),
      ),
    );
    focus.requestFocus();
    await tester.pump();
    expect(shortcutInputFocused(), isTrue);
    expect(shortcutFocusBlocked(), isTrue);
    final context = tester.element(find.byType(TextField));
    showDialog<void>(
      context: context,
      builder: (_) => const AlertDialog(content: TextField(autofocus: true)),
    );
    await tester.pumpAndSettle();
    expect(shortcutFocusBlocked(), isTrue);
  });
}
