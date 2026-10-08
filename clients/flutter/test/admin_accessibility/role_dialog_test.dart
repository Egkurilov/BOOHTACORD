import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/features/admin/role_permissions/panel.dart';
import 'package:boohtacord_desktop/src/features/admin/role_permissions/lifecycle/state.dart';
import 'package:boohtacord_desktop/src/features/authorization/permissions/model.dart';

import 'fixture.dart';

void main() {
  for (final width in [390.0, 600.0, 1440.0]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets(
        'role confirmation reduced motion, Escape, Back and safe geometry $width / $scale',
        (tester) async {
          await mountAdmin(
            tester,
            size: Size(width, 900),
            scale: scale,
            reducedMotion: true,
            insets: const EdgeInsets.only(bottom: 300),
            padding: const EdgeInsets.only(top: 32, bottom: 34),
          );
          final roles = find.byKey(const ValueKey('admin-section-tab-roles'));
          await tester.ensureVisible(roles);
          await tester.tap(roles);
          await tester.pumpAndSettle();
          final permission = find.widgetWithText(
            CheckboxListTile,
            'Удалять текстовые каналы',
          );
          await revealAdminControl(tester, permission);
          await tester.tap(permission);
          await tester.pumpAndSettle();
          final save = find.widgetWithText(FilledButton, 'Сохранить');
          await revealAdminControl(tester, save);
          await tester.pumpAndSettle();
          final focus = Focus.of(
            tester.element(
              find.descendant(of: save, matching: find.text('Сохранить')),
            ),
          );
          focus.requestFocus();
          await tester.pumpAndSettle();
          final initiator = FocusManager.instance.primaryFocus;
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          await tester.pumpAndSettle();
          final dialog = find.byType(AlertDialog);
          expect(find.text('Выдать права удаления?'), findsOneWidget);
          expect(
            ModalRoute.of(tester.element(dialog))!.transitionDuration,
            Duration.zero,
          );
          final apply = find.widgetWithText(FilledButton, 'Выдать');
          expect(tester.getSize(apply).height, greaterThanOrEqualTo(44));
          expect(tester.getRect(apply).bottom, lessThanOrEqualTo(600));
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await tester.pumpAndSettle();
          expect(dialog, findsNothing);
          expect(initiator?.hasFocus, true);
          expect(
            tester
                .state<RolePermissionsState>(find.byType(RolePermissionsPanel))
                .draft[GuildPermission.textDelete],
            true,
          );
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          await tester.pumpAndSettle();
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          expect(dialog, findsNothing);
          expect(initiator?.hasFocus, true);
          expect(
            find.byKey(const ValueKey('admin-workspace-header')),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
