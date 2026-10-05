import 'package:boohtacord_desktop/src/features/session/own_sessions/controller.dart';
import 'package:boohtacord_desktop/src/features/session/own_sessions/model.dart';
import 'package:boohtacord_desktop/src/features/session/own_sessions/view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('session rows protect current and revoke others is available', (
    tester,
  ) async {
    String? revokedOwner;
    final state = OwnSessionsController(
      read: (_) async => OwnSessionPage(
        accountId: 'A',
        sessions: [
          for (final current in [true, false])
            OwnSession(
              id: current ? 'current' : 'other',
              label: 'Вход',
              createdAt: DateTime(2026),
              lastActiveAt: DateTime(2026),
              current: current,
            ),
        ],
      ),
      revokeOne: (_, _) async {},
      revokeOthersRequest: (owner) async {
        revokedOwner = owner;
      },
    )..setAccount('A');
    await state.refresh();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: OwnSessionsView(state: state)),
      ),
    );
    expect(find.textContaining('Этот сеанс'), findsOneWidget);
    final buttons = tester
        .widgetList<OutlinedButton>(
          find.widgetWithText(OutlinedButton, 'Завершить'),
        )
        .toList();
    expect(buttons.first.onPressed, isNull);
    expect(buttons.last.onPressed, isNotNull);
    await tester.tap(find.text('Завершить все остальные'));
    await tester.pumpAndSettle();
    expect(revokedOwner, 'A');
    await tester.pumpWidget(const SizedBox());
    state.dispose();
  });
}
