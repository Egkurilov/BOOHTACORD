import 'dart:convert';

import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/screens/auth_screen.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

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

  testWidgets('login submits a shorter existing password', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    final requests = <http.Request>[];
    final state = AppState(
      ApiClient(
        client: MockClient((request) async {
          requests.add(request);
          return http.Response(
            jsonEncode({
              'error': {
                'code': 'UNAUTHENTICATED',
                'message': 'Неверный логин или пароль',
              },
            }),
            401,
            headers: {'content-type': 'application/json'},
          );
        }),
      ),
    )..phase = AppPhase.signedOut;
    addTearDown(state.dispose);

    await tester.pumpWidget(MaterialApp(home: AuthScreen(state: state)));
    await tester.enterText(
      find.byKey(const ValueKey('auth-login-field')),
      'existing_user',
    );
    await tester.enterText(
      find.byKey(const ValueKey('auth-password-field')),
      'shortpass',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Войти'));
    await tester.pumpAndSettle();

    expect(requests, hasLength(1));
    expect(requests.single.url.path, '/api/v1/auth/login');
    expect(
      (jsonDecode(requests.single.body) as Map<String, dynamic>)['password'],
      'shortpass',
    );
  });

  testWidgets('switching auth mode clears the previous error', (tester) async {
    final state = AppState(ApiClient())..phase = AppPhase.signedOut;
    addTearDown(state.dispose);
    state.reportError('Неверный логин или пароль');

    await tester.pumpWidget(MaterialApp(home: AuthScreen(state: state)));
    expect(find.text('Неверный логин или пароль'), findsOneWidget);

    await tester.tap(find.text('Регистрация'));
    await tester.pumpAndSettle();

    expect(find.text('Неверный логин или пароль'), findsNothing);
  });

  testWidgets('registration enforces server password length limits', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({});
    var requestCount = 0;
    final state = AppState(
      ApiClient(
        client: MockClient((_) async {
          requestCount++;
          return http.Response('', 204);
        }),
      ),
    )..phase = AppPhase.signedOut;
    addTearDown(state.dispose);

    await tester.pumpWidget(MaterialApp(home: AuthScreen(state: state)));
    await tester.tap(find.text('Регистрация'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('auth-login-field')),
      'new_member',
    );
    await tester.enterText(
      find.byKey(const ValueKey('auth-password-field')),
      'shortpass12',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Создать аккаунт'));
    await tester.pumpAndSettle();

    expect(requestCount, 0);
    expect(
      find.text('Пароль должен содержать не менее 12 символов'),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const ValueKey('auth-password-field')),
      'x' * 129,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Создать аккаунт'));
    await tester.pumpAndSettle();
    expect(requestCount, 0);
    expect(
      find.text('Пароль должен содержать не более 128 символов'),
      findsOneWidget,
    );
  });
}
