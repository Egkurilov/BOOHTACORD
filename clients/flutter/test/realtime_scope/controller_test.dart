import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/core/session/scope.dart';
import 'package:boohtacord_desktop/src/features/realtime/lifecycle/controller.dart';

import 'fakes.dart';

void main() {
  test('a socket opened after scope closure is immediately closed', () async {
    final api = RealtimeApiFake();
    final scope = SessionScope();
    final owner = RealtimeController(
      api,
      scope,
      isReady: () => true,
      expire: () async {},
      invalidatePresence: () {},
      dispatch: (_) {},
    );
    addTearDown(owner.dispose);
    final pending = owner.connect();
    scope.close();
    await owner.close();
    final socket = SocketFake();
    api.opening.complete(socket);
    await pending;
    expect(socket.closed, isTrue);
    expect(owner.socket, isNull);
    expect(owner.connected, isFalse);
  });

  test(
    'an old connection session check cannot expire the new account',
    () async {
      final api = RealtimeApiFake();
      final scope = SessionScope();
      var expirations = 0;
      final owner = RealtimeController(
        api,
        scope,
        isReady: () => true,
        expire: () async {
          expirations++;
        },
        invalidatePresence: () {},
        dispatch: (_) {},
      );
      addTearDown(owner.dispose);
      final socket = SocketFake();
      api.opening.complete(socket);
      await owner.connect();
      await socket.close();
      await api.checking.future;
      scope.close();
      scope.begin();
      api.restored.complete(null);
      await Future<void>.delayed(Duration.zero);
      expect(expirations, 0);
      expect(owner.retry, isNull);
    },
  );
}
