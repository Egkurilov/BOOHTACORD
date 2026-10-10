import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/features/session/own_sessions/controller.dart';
import 'package:boohtacord_desktop/src/features/session/own_sessions/model.dart';
import 'package:boohtacord_desktop/src/features/session/own_sessions/view.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:boohtacord_desktop/src/screens/profile_screen.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:boohtacord_desktop/src/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'capture_support.dart';

class _SettingsCaptureApi extends ApiClient {
  @override
  Future<OwnSessionPage> ownSessions([String? cursor]) async =>
      const OwnSessionPage(accountId: 'account-1', sessions: []);
}

class _SettingsCaptureState extends AppState {
  _SettingsCaptureState() : super(_SettingsCaptureApi());

  int logoutCalls = 0;

  @override
  Future<void> logout() async {
    logoutCalls++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'captures the profile logout confirmation at mobile source size',
    (tester) async {
      if (!uiuxVisualCaptureEnabled) return;
      await loadUiuxVisualCaptureFonts();
      tester.view.devicePixelRatio = 3;
      tester.view.physicalSize = const Size(1179, 2556);
      addTearDown(tester.view.reset);

      final state = _SettingsCaptureState()
        ..phase = AppPhase.ready
        ..profile = const OwnProfile(
          accountId: 'account-1',
          login: 'synthetic-qa',
          displayName: 'Synthetic QA',
          role: 'MEMBER',
        );
      addTearDown(state.dispose);
      final rootKey = GlobalKey();

      await tester.pumpWidget(
        RepaintBoundary(
          key: rootKey,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: guildTheme(),
            home: Scaffold(body: ProfileScreen(state: state)),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('profile-tab-security')));
      await tester.pumpAndSettle();
      final logout = find.widgetWithText(OutlinedButton, 'Выйти из аккаунта');
      await tester.ensureVisible(logout);
      await tester.tap(logout);
      await tester.pumpAndSettle();

      expect(find.text('Подтвердите выход из аккаунта'), findsOneWidget);
      expect(
        find.text(
          'Голосовое подключение завершится, а личные данные исчезнут '
          'с этого экрана. Выйти из аккаунта?',
        ),
        findsOneWidget,
      );
      expect(state.logoutCalls, 0);
      await captureUiuxBoundary(
        tester,
        find.byKey(rootKey),
        fileName: 'flutter-profile-logout-confirmation-mobile-393x852@3x.png',
        pixelRatio: 3,
      );
      await tester.tap(find.text('Отмена'));
      await tester.pumpAndSettle();
      expect(state.logoutCalls, 0);
    },
  );

  testWidgets('captures confirmation before revoking other sessions', (
    tester,
  ) async {
    if (!uiuxVisualCaptureEnabled) return;
    await loadUiuxVisualCaptureFonts();
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(1179, 2556);
    addTearDown(tester.view.reset);

    final state = OwnSessionsController(
      read: (_) async => OwnSessionPage(
        accountId: 'account-1',
        sessions: [
          for (final current in [true, false])
            OwnSession(
              id: current ? 'current' : 'other',
              label: current ? 'Это устройство' : 'Другой компьютер',
              createdAt: DateTime(2026),
              lastActiveAt: DateTime(2026),
              current: current,
            ),
        ],
      ),
      revokeOne: (_, _) async {},
      revokeOthersRequest: (_) async {},
    )..setAccount('account-1');
    await state.refresh();
    addTearDown(state.dispose);
    final rootKey = GlobalKey();

    await tester.pumpWidget(
      RepaintBoundary(
        key: rootKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: guildTheme(),
          home: Scaffold(body: OwnSessionsView(state: state)),
        ),
      ),
    );
    await tester.tap(find.text('Завершить все остальные'));
    await tester.pumpAndSettle();

    expect(find.text('Подтвердите завершение сеансов'), findsOneWidget);
    expect(
      find.text(
        'Все остальные сеансы потеряют доступ к сообщениям и голосу. '
        'Текущий сеанс останется активным. Продолжить?',
      ),
      findsOneWidget,
    );
    await captureUiuxBoundary(
      tester,
      find.byKey(rootKey),
      fileName:
          'flutter-settings-revoke-sessions-confirmation-mobile-393x852@3x.png',
      pixelRatio: 3,
    );
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
  });
}
