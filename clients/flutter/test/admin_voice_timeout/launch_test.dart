import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:boohtacord_desktop/src/screens/admin_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'launch_fixture.dart';

void main() {
  for (final width in [390.0, 1440.0]) {
    testWidgets('real admin launches authorized timeout at width $width', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 900);
      addTearDown(tester.view.reset);
      final api = TimeoutLaunchApi()
        ..accounts = [
          AdminAccount(
            accountId: target,
            login: 'synthetic',
            displayName: 'Synthetic member',
            role: 'MEMBER',
            blocked: false,
            createdAt: DateTime.utc(2026),
          ),
        ];
      final state = AppState(api)..topology = api.current;
      addTearDown(state.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: AdminScreen(state: state)),
        ),
      );
      await tester.pumpAndSettle();
      final trigger = find.byKey(
        ValueKey(
          width > 1000
              ? 'admin-member-actions:$target'
              : 'voice-timeout-account:$target',
        ),
      );
      await tester.ensureVisible(trigger);
      final triggerContent = width > 1000
          ? find.descendant(of: trigger, matching: find.byType(Icon)).first
          : find.descendant(of: trigger, matching: find.byType(Text)).first;
      final triggerFocus = width > 1000
          ? tester
                .widget<Focus>(
                  find.byKey(
                    const ValueKey('admin-member-action-focus:$target'),
                  ),
                )
                .focusNode!
          : Focus.of(tester.element(triggerContent));
      triggerFocus.requestFocus();
      await tester.pump();
      if (width > 1000) {
        await tester.tap(trigger);
        await tester.pumpAndSettle();
      }
      final action = find.text('Голосовой тайм-аут');
      await tester.ensureVisible(action);
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(api.reads, 1);
      expect(api.readAccount, target);
      expect(find.text('Длительность'), findsOneWidget);
      expect(find.text('Ограничение не активно.'), findsOneWidget);
      expect(state.voiceChannel, isNull);
      expect(state.room, isNull);
      expect(tester.takeException(), isNull);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
      expect(api.reads, 1);
      expect(triggerFocus.hasFocus, isTrue);
      if (width > 1000) {
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(find.text('Голосовой тайм-аут'), findsOneWidget);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(triggerFocus.hasFocus, isTrue);
      }
    });
  }
}
