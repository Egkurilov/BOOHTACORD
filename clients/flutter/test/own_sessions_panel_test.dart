import 'package:boohtacord_desktop/src/features/session/own_sessions/controller.dart';
import 'package:boohtacord_desktop/src/features/session/own_sessions/model.dart';
import 'package:boohtacord_desktop/src/features/session/own_sessions/view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('session mutations require an explicit confirmation', (
    tester,
  ) async {
    String? revokedOwner;
    var revokedOne = 0;
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
      revokeOne: (_, _) async {
        revokedOne++;
      },
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
    expect(find.text('Подтвердите завершение сеансов'), findsOneWidget);
    expect(revokedOwner, isNull);
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
    expect(revokedOwner, isNull);

    await tester.tap(find.text('Завершить все остальные'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Завершить сеансы'));
    await tester.pumpAndSettle();
    expect(revokedOwner, 'A');

    await tester.tap(find.widgetWithText(OutlinedButton, 'Завершить').last);
    await tester.pumpAndSettle();
    expect(find.text('Подтвердите завершение сеанса'), findsOneWidget);
    expect(revokedOne, 0);
    await tester.tap(find.widgetWithText(FilledButton, 'Завершить сеанс'));
    await tester.pumpAndSettle();
    expect(revokedOne, 1);
    await tester.pumpWidget(const SizedBox());
    state.dispose();
  });

  testWidgets('stale session confirmation closes without revoking', (
    tester,
  ) async {
    var revoked = false;
    final state = OwnSessionsController(
      read: (owner) async => OwnSessionPage(
        accountId: owner ?? 'A',
        sessions: [
          OwnSession(
            id: 'other',
            label: 'Ноутбук',
            createdAt: DateTime(2026),
            lastActiveAt: DateTime(2026),
            current: false,
          ),
        ],
      ),
      revokeOne: (_, _) async {
        revoked = true;
      },
      revokeOthersRequest: (_) async {},
    )..setAccount('A');
    await state.refresh();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: OwnSessionsView(state: state)),
      ),
    );

    await tester.tap(find.widgetWithText(OutlinedButton, 'Завершить'));
    await tester.pumpAndSettle();
    expect(find.text('Подтвердите завершение сеанса'), findsOneWidget);
    expect(
      find.text(
        'Сеанс «Ноутбук» потеряет доступ к сообщениям и голосу. Завершить его?',
      ),
      findsOneWidget,
    );

    state.setAccount('B');
    await tester.pumpAndSettle();
    expect(find.text('Подтвердите завершение сеанса'), findsNothing);
    expect(revoked, isFalse);

    await tester.pumpWidget(const SizedBox());
    state.dispose();
  });
}
