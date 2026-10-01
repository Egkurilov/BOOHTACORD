import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:boohtacord_desktop/src/features/session/lifecycle/controller.dart';

import 'fake_api.dart';
import 'fake_effects.dart';

void main() {
  test('logout closes admission before asynchronous teardown', () async {
    final api = SessionFakeApi()..leaving = Completer<void>();
    var cleared = 0;
    final session = SessionController(
      api,
      effects: effects(
        clear: () async {
          cleared++;
        },
      ),
    );
    addTearDown(session.dispose);
    session.phase = AppPhase.ready;
    session.user = const SessionUser(accountId: 'account', role: 'MEMBER');
    final admitted = session.scope.capture();
    final closing = session.logout();
    await Future<void>.delayed(Duration.zero);
    expect(admitted.isActive, isFalse);
    expect(session.scope.capture().isActive, isFalse);
    api.leaving!.complete();
    await closing;
    expect(session.phase, AppPhase.signedOut);
    expect(session.user, isNull);
    expect(cleared, 1);
  });

  test(
    'a failed logout resumes admission without reviving previous operations',
    () async {
      final api = SessionFakeApi()..failLogout = true;
      final events = <String>[];
      final session = SessionController(
        api,
        effects: effects(
          invalidate: () => events.add('invalidate'),
          resume: () async {
            events.add('resume');
          },
        ),
      );
      addTearDown(session.dispose);
      session.phase = AppPhase.ready;
      final before = session.scope.capture();
      await session.logout();
      expect(session.phase, AppPhase.ready);
      expect(session.logoutError, 'logout failed');
      expect(before.isActive, isFalse);
      expect(session.scope.capture().isActive, isTrue);
      expect(events, ['invalidate', 'resume']);
    },
  );

  test(
    'authentication waits for account teardown before issuing credentials',
    () async {
      final api = SessionFakeApi()..leaving = Completer<void>();
      final session = SessionController(api, effects: effects());
      addTearDown(session.dispose);
      final closing = session.logout();
      await Future<void>.delayed(Duration.zero);
      final login = session.authenticate(
        'account',
        'password',
        register: false,
      );
      await Future<void>.delayed(Duration.zero);
      expect(api.authentications, 0);
      api.leaving!.complete();
      await closing;
      await login;
      expect(api.authentications, 1);
      expect(session.phase, AppPhase.ready);
    },
  );

  test(
    'unauthorized logout expires the session after teardown fails',
    () async {
      final api = SessionFakeApi()..failLogout = true;
      final session = SessionController(api, effects: effects());
      addTearDown(session.dispose);
      session.phase = AppPhase.ready;
      session.user = const SessionUser(accountId: 'account', role: 'MEMBER');
      Future<void>? expiry;
      api.loggingOut = () => expiry = session.expire();
      await session.logout();
      await expiry;
      expect(session.phase, AppPhase.signedOut);
      expect(session.user, isNull);
      expect(session.scope.capture().isActive, isFalse);
    },
  );
}
