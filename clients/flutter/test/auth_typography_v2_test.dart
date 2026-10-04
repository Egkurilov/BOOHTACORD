import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/screens/auth_screen.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final width in [390.0, 1440.0]) {
    testWidgets('auth typography follows web at ${width.toInt()} px', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 900);
      addTearDown(tester.view.reset);
      final state = AppState(ApiClient())..phase = AppPhase.signedOut;
      addTearDown(state.dispose);

      await tester.pumpWidget(MaterialApp(home: AuthScreen(state: state)));

      final eyebrow = tester.widget<Text>(
        find.text('На своём сервере · одна гильдия'),
      );
      expect(eyebrow.style?.fontSize, width <= 720 ? 16 : 18);
      expect(eyebrow.style?.fontWeight, FontWeight.w700);
      final heading = tester.widget<Text>(find.text('Voice Platform'));
      expect(heading.style?.fontSize, 24);
      expect(heading.style?.fontWeight, FontWeight.w600);
      final submit = tester.widget<Text>(
        find.descendant(
          of: find.byType(FilledButton),
          matching: find.text('Войти'),
        ),
      );
      expect(submit.style?.fontWeight, FontWeight.w500);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    });
  }
}
