import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/widgets/confirmation_dialog.dart';

void main() {
  testWidgets(
    'confirmation Escape cancels and restores initiator focus; Tab remains in dialog',
    (tester) async {
      final trigger = FocusNode();
      addTearDown(trigger.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                focusNode: trigger,
                onPressed: () => showConfirmationDialog<bool>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: const Text('Подтвердить действие'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        child: const Text('Отмена'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(dialogContext, true),
                        child: const Text('Применить'),
                      ),
                    ],
                  ),
                ),
                child: const Text('Открыть'),
              ),
            ),
          ),
        ),
      );
      trigger.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      for (var i = 0; i < 5; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(trigger.hasFocus, false);
        expect(
          FocusManager.instance.primaryFocus?.context
              ?.findAncestorWidgetOfExactType<AlertDialog>(),
          isNotNull,
        );
      }
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      for (var i = 0; i < 5; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(trigger.hasFocus, false);
        expect(
          FocusManager.instance.primaryFocus?.context
              ?.findAncestorWidgetOfExactType<AlertDialog>(),
          isNotNull,
        );
      }
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(trigger.hasFocus, true);
    },
  );
}
