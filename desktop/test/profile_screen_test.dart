import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/screens/profile_screen.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('announces profile loading status', (tester) async {
    final state = AppState(ApiClient())..profileLoading = true;
    addTearDown(state.dispose);

    await tester.pumpWidget(MaterialApp(home: ProfileScreen(state: state)));

    final loading = find.text('Загружаем профиль…');
    expect(loading, findsOneWidget);
    expect(tester.getSemantics(loading).flagsCollection.isLiveRegion, isTrue);
  });

  testWidgets('announces profile loading errors accessibly', (tester) async {
    final state = AppState(ApiClient())
      ..profileLoadError = 'Не удалось загрузить профиль.';
    addTearDown(state.dispose);

    await tester.pumpWidget(MaterialApp(home: ProfileScreen(state: state)));

    final error = find.text('Не удалось загрузить профиль.');
    expect(error, findsOneWidget);
    expect(tester.getSemantics(error).flagsCollection.isLiveRegion, isTrue);
    expect(find.text('Изменить пароль'), findsNothing);
  });
}
