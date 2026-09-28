import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:boohtacord_desktop/src/screens/profile_screen.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
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
    final state = AppState(ApiClient());
    addTearDown(state.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ProfileScreen(state: state)),
      ),
    );

    expect(find.text('Уведомления'), findsOneWidget);
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
  });

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
      tester.getSemantics(find.text('Профиль')).flagsCollection.isHeader,
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
}
