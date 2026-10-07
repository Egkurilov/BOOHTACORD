import 'package:boohtacord_desktop/src/core/ui/confirmation_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('confirmation stays modal until an explicit choice or Escape', (
    tester,
  ) async {
    final openerFocus = FocusNode();
    addTearDown(openerFocus.dispose);
    Future<bool?>? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              focusNode: openerFocus,
              onPressed: () => result = showConfirmationDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Подтверждение действия'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Отмена'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Продолжить'),
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

    openerFocus.requestFocus();
    await tester.pump();
    expect(openerFocus.hasFocus, isTrue);
    await tester.tap(find.text('Открыть'));
    await tester.pumpAndSettle();

    final title = find.text('Подтверждение действия');
    final route = ModalRoute.of(tester.element(title))!;
    expect(route.barrierDismissible, isFalse);
    expect(route.traversalEdgeBehavior, TraversalEdgeBehavior.closedLoop);

    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();
    expect(title, findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(title, findsNothing);
    expect(await result, isNull);
    expect(openerFocus.hasFocus, isTrue);
  });
}
