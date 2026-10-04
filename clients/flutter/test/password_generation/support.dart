import 'dart:async';

import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/screens/auth_screen.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:boohtacord_desktop/src/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final passwordField = find.byKey(const ValueKey('auth-password-field'));
final generateButton = find.byKey(const ValueKey('auth-generate-password'));
EditableText passwordInput(WidgetTester tester) => tester.widget<EditableText>(
  find.descendant(of: passwordField, matching: find.byType(EditableText)),
);

Future<void> press(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<AppState> mountRegistration(
  WidgetTester tester,
  Size size, {
  AppState? state,
  GlobalKey? captureKey,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  final owner = state ?? (AppState(ApiClient())..phase = AppPhase.signedOut);
  addTearDown(owner.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: guildTheme(),
      home: RepaintBoundary(
        key: captureKey,
        child: AuthScreen(state: owner),
      ),
    ),
  );
  expect(generateButton, findsNothing);
  await press(tester, find.text('Регистрация'));
  return owner;
}

class PendingAuthenticationState extends AppState {
  PendingAuthenticationState() : super(ApiClient()) {
    phase = AppPhase.signedOut;
  }
  final completion = Completer<void>();
  int calls = 0;
  bool receivedGeneratedPassword = false;
  @override
  Future<void> authenticate(
    String login,
    String password, {
    required bool register,
  }) {
    calls++;
    receivedGeneratedPassword = register && password.length == 24;
    return completion.future;
  }
}
