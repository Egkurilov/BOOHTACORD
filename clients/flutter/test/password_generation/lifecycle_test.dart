import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

void main() {
  for (final unmountFirst in [false, true]) {
    testWidgets(
      'clears secret on ${unmountFirst ? 'dispose during request' : 'authentication success'}',
      (tester) async {
        final state = PendingAuthenticationState();
        await mountRegistration(tester, const Size(1440, 900), state: state);
        await tester.enterText(
          find.byKey(const ValueKey('auth-login-field')),
          'new_member',
        );
        await press(tester, generateButton);
        final controller = passwordInput(tester).controller;
        await press(
          tester,
          find.widgetWithText(FilledButton, 'Создать аккаунт'),
        );
        expect(state.calls, 1);
        expect(state.receivedGeneratedPassword, isTrue);
        expect(tester.widget<OutlinedButton>(generateButton).onPressed, isNull);
        if (unmountFirst) {
          await tester.pumpWidget(const SizedBox());
          expect(controller.text.isEmpty, isTrue);
        }
        state.completion.complete();
        await tester.pumpAndSettle();
        if (!unmountFirst) {
          expect(controller.text.isEmpty, isTrue);
          expect(passwordInput(tester).obscureText, isTrue);
          expect(find.text('Надёжный пароль сгенерирован'), findsNothing);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}
