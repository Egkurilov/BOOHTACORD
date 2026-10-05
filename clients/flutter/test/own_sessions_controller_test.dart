import 'dart:async';

import 'package:boohtacord_desktop/src/features/session/own_sessions/controller.dart';
import 'package:boohtacord_desktop/src/features/session/own_sessions/model.dart';
import 'package:flutter_test/flutter_test.dart';

OwnSession row(bool current) => OwnSession(
  id: current ? 'current' : 'other',
  label: 'Вход',
  createdAt: DateTime(2026),
  lastActiveAt: DateTime(2026),
  current: current,
);
OwnSessionPage page(String owner) =>
    OwnSessionPage(accountId: owner, sessions: [row(true), row(false)]);
void main() {
  test('account change and screen disposal invalidate pending reads', () async {
    final pending = Completer<OwnSessionPage>();
    final state = OwnSessionsController(
      read: (_) => pending.future,
      revokeOne: (_, _) async {},
      revokeOthersRequest: (_) async {},
    );
    state.setAccount('A');
    final read = state.refresh();
    state.setAccount('B');
    pending.complete(page('A'));
    await read;
    expect(state.items, isEmpty);
    expect(state.error, isNull);
    state.dispose();
  });
  test('mismatched owner is rejected before displaying sessions', () async {
    final state = OwnSessionsController(
      read: (_) async => page('B'),
      revokeOne: (_, _) async {},
      revokeOthersRequest: (_) async {},
    );
    state.setAccount('A');
    await state.refresh();
    expect(state.items, isEmpty);
    expect(state.error, contains('Аккаунт'));
    state.dispose();
  });
  test(
    'current session is protected and revoke others preserves owner',
    () async {
      String? target;
      var calls = 0;
      final state = OwnSessionsController(
        read: (_) async => page('A'),
        revokeOne: (_, _) async {
          calls++;
        },
        revokeOthersRequest: (owner) async {
          target = owner;
        },
      );
      state.setAccount('A');
      await state.refresh();
      await state.revoke('current');
      expect(calls, 0);
      await state.revokeOthers();
      expect(target, 'A');
      state.dispose();
    },
  );
}
