import 'dart:io';
import 'dart:ui' show SemanticsRole, Tristate;

import 'package:boohtacord_desktop/src/app_version.dart';
import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:boohtacord_desktop/src/screens/profile_screen.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:boohtacord_desktop/src/services/native_notifications.dart';
import 'package:boohtacord_desktop/src/widgets/authenticated_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('announces profile loading status', (tester) async {
    final state = AppState(ApiClient())..profileLoading = true;
    addTearDown(state.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ProfileScreen(state: state)),
      ),
    );

    final loading = find.text('Загружаем профиль…');
    expect(loading, findsOneWidget);
    expect(tester.getSemantics(loading).flagsCollection.isLiveRegion, isTrue);
  });

  testWidgets('shows the app version and build number in profile settings', (
    tester,
  ) async {
    final state = AppState(ApiClient())
      ..profile = const OwnProfile(
        accountId: 'account-1',
        login: 'member',
        displayName: 'Участник',
        role: 'MEMBER',
      );
    addTearDown(state.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ProfileScreen(state: state)),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('profile-tab-about')));
    await tester.pumpAndSettle();

    expect(find.text(appVersionLabel), findsOneWidget);
  });

  test(
    'app version label stays synchronized with the package release version',
    () {
      final packageVersion = RegExp(
        r'^version:\s*(\S+)',
        multiLine: true,
      ).firstMatch(File('pubspec.yaml').readAsStringSync())?.group(1);

      expect(packageVersion, '$appVersionName+$appBuildNumber');
      expect(appVersionLabel, 'Версия $appVersionName ($appBuildNumber)');
    },
  );

  testWidgets('announces profile loading errors accessibly', (tester) async {
    final state = AppState(ApiClient())
      ..profileLoadError = 'Не удалось загрузить профиль.';
    addTearDown(state.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ProfileScreen(state: state)),
      ),
    );

    final error = find.text('Не удалось загрузить профиль.');
    expect(error, findsOneWidget);
    expect(tester.getSemantics(error).flagsCollection.isLiveRegion, isTrue);
    expect(find.text('Изменить пароль'), findsNothing);
  });

  testWidgets('explains generic native notification privacy', (tester) async {
    final state =
        AppState(
            ApiClient(),
            nativeNotifications: NativeNotificationService(
              supportedOnCurrentPlatform: true,
            ),
          )
          ..profile = const OwnProfile(
            accountId: 'account-1',
            login: 'member',
            displayName: 'Участник',
            role: 'MEMBER',
          );
    addTearDown(state.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ProfileScreen(state: state)),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('profile-tab-notifications')));
    await tester.pumpAndSettle();

    expect(find.text('Уведомления'), findsNWidgets(2));
    expect(
      find.textContaining('Содержимое личных сообщений не отображается.'),
      findsOneWidget,
    );
  });

  testWidgets('profile name field leaves web code point validation to save', (
    tester,
  ) async {
    final state = AppState(ApiClient())
      ..profile = const OwnProfile(
        accountId: 'account-1',
        login: 'member',
        displayName: 'Участник',
        role: 'MEMBER',
      );
    addTearDown(state.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ProfileScreen(state: state)),
      ),
    );

    expect(
      tester.widget<TextField>(find.byType(TextField).first).maxLength,
      isNull,
    );
    expect(
      tester
          .widget<AuthenticatedAvatar>(find.byType(AuthenticatedAvatar))
          .radius,
      36,
    );
    expect(
      tester
          .widget<ConstrainedBox>(
            find.byKey(const ValueKey('profile-name-form-width')),
          )
          .constraints
          .maxWidth,
      480,
    );
  });

  testWidgets('centers profile content at web desktop max width', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final state = AppState(ApiClient());
    addTearDown(state.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ProfileScreen(state: state)),
      ),
    );

    final content = tester.getRect(
      find.byKey(const ValueKey('profile-settings-content')),
    );
    expect(content.width, 720);
    expect(content.left, 360);
  });

  testWidgets(
    'uses web compact inset and full profile width on Android sizes',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final state = AppState(ApiClient());
      addTearDown(state.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ProfileScreen(state: state)),
        ),
      );

      final content = tester.getRect(
        find.byKey(const ValueKey('profile-settings-content')),
      );
      expect(content.width, 358);
      expect(content.left, 16);
    },
  );

  for (final width in [320.0, 390.0, 1440.0]) {
    testWidgets(
      'profile settings keep save reachable at $width px with 2x text',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 844);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final state = AppState(ApiClient())
          ..profile = const OwnProfile(
            accountId: 'account-1',
            login: 'long-member-login',
            displayName: 'Длинное отображаемое имя участника',
            role: 'ADMINISTRATOR',
          );
        addTearDown(state.dispose);

        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: Scaffold(body: ProfileScreen(state: state)),
          ),
        );
        await tester.pumpAndSettle();

        final save = find.widgetWithText(FilledButton, 'Сохранить профиль');
        expect(save, findsOneWidget);
        await tester.ensureVisible(save);
        final saveRect = tester.getRect(save);
        expect(saveRect.left, greaterThanOrEqualTo(0));
        expect(saveRect.right, lessThanOrEqualTo(width));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('moves keyboard focus to the profile heading like web', (
    tester,
  ) async {
    final state = AppState(ApiClient());
    addTearDown(state.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ProfileScreen(state: state)),
      ),
    );
    await tester.pump();

    expect(
      tester
          .widget<Focus>(
            find.byKey(const ValueKey('profile-screen-title-focus')),
          )
          .focusNode
          ?.hasFocus,
      isTrue,
    );
    expect(
      tester
          .getSemantics(
            find.descendant(
              of: find.byKey(const ValueKey('profile-screen-title-focus')),
              matching: find.text('Профиль'),
            ),
          )
          .flagsCollection
          .isHeader,
      isTrue,
    );
  });

  testWidgets('profile mutation errors are announced as live regions', (
    tester,
  ) async {
    final state = AppState(ApiClient())
      ..profile = const OwnProfile(
        accountId: 'account-1',
        login: 'member',
        displayName: 'Участник',
        role: 'MEMBER',
      )
      ..error = 'Имя должно содержать от 1 до 64 символов.';
    addTearDown(state.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ProfileScreen(state: state)),
      ),
    );

    final error = find.text('Имя должно содержать от 1 до 64 символов.');
    await tester.scrollUntilVisible(
      error,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(error, findsOneWidget);
    expect(tester.getSemantics(error).flagsCollection.isLiveRegion, isTrue);
  });

  testWidgets('profile settings use the web tab layout and selected panels', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final state = AppState(ApiClient())
      ..profile = const OwnProfile(
        accountId: 'account-1',
        login: 'member',
        displayName: 'Участник',
        role: 'MEMBER',
      );
    addTearDown(state.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ProfileScreen(state: state)),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('profile-tabs-semantics')),
      findsOneWidget,
    );
    expect(
      tester
          .getSemantics(find.byKey(const ValueKey('profile-tabs-semantics')))
          .getSemanticsData()
          .role,
      SemanticsRole.tabBar,
    );
    expect(find.byKey(const ValueKey('profile-tab-profile')), findsOneWidget);
    expect(
      tester
          .getSemantics(find.byKey(const ValueKey('profile-tab-profile')))
          .getSemanticsData()
          .flagsCollection
          .isSelected,
      Tristate.isTrue,
    );

    await tester.tap(find.byKey(const ValueKey('profile-tab-security')));
    await tester.pumpAndSettle();
    expect(find.text('Изменить пароль'), findsOneWidget);
    expect(find.text('Отображаемое имя'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('profile-tab-notifications')));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Содержимое личных сообщений не отображается.'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('profile-tab-about')));
    await tester.pumpAndSettle();
    expect(find.text(appVersionLabel), findsOneWidget);
    semantics.dispose();
  });
}
