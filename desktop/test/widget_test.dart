import 'package:boohtacord_desktop/src/app.dart';
import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows a branded loading state while session is restored', (
    tester,
  ) async {
    final state = AppState(ApiClient());
    await tester.pumpWidget(BoohtacordApp(state: state));
    expect(find.text('Подключаемся к гильдии…'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
  });

  testWidgets('shows maintenance banner without blocking the client', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.reset);
    final state = AppState(ApiClient())..maintenanceActive = true;
    await tester.pumpWidget(BoohtacordApp(state: state));

    expect(
      find.text(
        'Идёт обновление: новые входы и подключения к голосу временно приостановлены.',
      ),
      findsOneWidget,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('maintenance-banner'))).height,
      44,
    );
    expect(find.text('Подключаемся к гильдии…'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('matches web maintenance banner geometry on mobile width', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 800);
    addTearDown(tester.view.reset);
    final state = AppState(ApiClient())..maintenanceActive = true;
    await tester.pumpWidget(BoohtacordApp(state: state));

    final notice = find.textContaining('Идёт обновление:');
    final text = tester.widget<Text>(notice);
    expect(text.style?.fontSize, 14);
    expect(text.style?.height, 20 / 14);
    expect(text.maxLines, isNull);
    expect(
      tester.getSize(find.byKey(const ValueKey('maintenance-banner'))).height,
      greaterThan(44),
    );
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('renders reset completion for a valid one-use link', (
    tester,
  ) async {
    final state = AppState(ApiClient());
    state.phase = AppPhase.signedOut;
    final token = List.filled(43, 'a').join();
    state.openPasswordResetLink(
      'https://v.bootybay.ru/reset-password#token=$token',
    );
    await tester.pumpWidget(BoohtacordApp(state: state));

    expect(find.text('Новый пароль'), findsNWidgets(2));
    expect(find.text('Повторите пароль'), findsOneWidget);
    expect(find.text('Изменить пароль'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });
}
