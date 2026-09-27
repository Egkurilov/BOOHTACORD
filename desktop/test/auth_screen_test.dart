import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/screens/auth_screen.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('auth card follows web width on Android portrait viewport', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final state = AppState(ApiClient())..phase = AppPhase.signedOut;
    addTearDown(state.dispose);

    await tester.pumpWidget(MaterialApp(home: AuthScreen(state: state)));

    expect(tester.getSize(find.byKey(const ValueKey('auth-card'))).width, 342);
    expect(find.text('Voice Platform'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('auth card uses web maximum width on desktop', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.reset);
    final state = AppState(ApiClient())..phase = AppPhase.signedOut;
    addTearDown(state.dispose);

    await tester.pumpWidget(MaterialApp(home: AuthScreen(state: state)));

    expect(tester.getSize(find.byKey(const ValueKey('auth-card'))).width, 440);
    expect(tester.takeException(), isNull);
  });

  testWidgets('login keeps focus and entered text through app-state rebuilds', (
    tester,
  ) async {
    final state = AppState(ApiClient())..phase = AppPhase.signedOut;
    addTearDown(state.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: AnimatedBuilder(
          animation: state,
          builder: (context, _) => AuthScreen(state: state),
        ),
      ),
    );

    final login = find.byKey(const ValueKey('auth-login-field'));
    await tester.tap(login);
    await tester.enterText(login, 'p');
    expect(tester.testTextInput.isVisible, isTrue);

    state.notifyListeners();
    await tester.pump();

    final field = tester.widget<EditableText>(
      find.descendant(of: login, matching: find.byType(EditableText)),
    );
    expect(field.controller.text, 'p');
    expect(field.focusNode.hasFocus, isTrue);
    expect(field.autocorrect, isFalse);
    expect(field.enableSuggestions, isFalse);
    expect(tester.testTextInput.isVisible, isTrue);
  });
}
