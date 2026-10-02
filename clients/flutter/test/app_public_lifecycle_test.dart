import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';

class PendingPublicApi extends ApiClient {
  final reset = Completer<void>();
  @override
  Future<void> completePasswordReset(String token, String password) =>
      reset.future;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'a previous reset completion cannot consume a newly opened link',
    () async {
      final api = PendingPublicApi();
      final state = AppState(api);
      addTearDown(state.dispose);
      final oldToken = 'a' * 43;
      final newToken = 'b' * 43;
      state.openPasswordResetLink(
        'https://v.bootybay.ru/reset-password#token=$oldToken',
      );
      final pending = state.completePasswordReset('password-value');
      state.openPasswordResetLink(
        'https://v.bootybay.ru/reset-password#token=$newToken',
      );
      api.reset.complete();
      expect(await pending, isFalse);
      expect(state.resetToken, newToken);
      expect(state.resetCompleted, isFalse);
    },
  );
}
