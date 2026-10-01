import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:boohtacord_desktop/src/features/session/lifecycle/controller.dart';

import 'fake_api.dart';

import 'fake_effects.dart';

void main() {
  test(
    'late startup response cannot restore an account after logout',
    () async {
      final api = SessionFakeApi()..restore = Completer<SessionUser?>();
      var ready = 0;
      final session = SessionController(
        api,
        effects: effects(
          ready: () async {
            ready++;
          },
        ),
      );
      addTearDown(session.dispose);
      final startup = session.initialize();
      await Future<void>.delayed(Duration.zero);
      await session.logout();
      api.restore!.complete(
        const SessionUser(accountId: 'old', role: 'MEMBER'),
      );
      await startup;
      expect(session.user, isNull);
      expect(session.phase, AppPhase.signedOut);
      expect(ready, 0);
    },
  );

  test('disposal prevents late startup notifications', () async {
    final api = SessionFakeApi()..restore = Completer<SessionUser?>();
    final session = SessionController(api, effects: effects());
    final startup = session.initialize();
    await Future<void>.delayed(Duration.zero);
    session.dispose();
    api.restore!.complete(null);
    await startup;
    expect(session.scope.capture().isActive, isFalse);
  });
}
