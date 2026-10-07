import 'package:boohtacord_desktop/src/features/admin/members/controller.dart';
import 'package:boohtacord_desktop/src/features/admin/members/panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_api.dart';

void main() {
  testWidgets('successful save reloads server version and restores row action focus', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = MembersApiFake()..pages[null] = AdminAccountPage(accounts: [member('a')]);
    api.onSave = (id, role, blocked, _) async {
      api.pages[null] = AdminAccountPage(accounts: [member(id, role: role, blocked: blocked, version: 2)]);
    };
    final controller = AdminMembersController(api);
    addTearDown(controller.dispose);
    await controller.load();
    controller.updateDraftRole('a', 'ADMINISTRATOR');
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: AdminMembersPanel(
      controller: controller, currentAccountId: 'self', voiceParticipantIds: const {},
    ))));
    await tester.tap(find.byKey(const ValueKey('admin-member-actions:a')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    final actionsFocus = tester.widget<Focus>(
      find.byKey(const ValueKey('admin-member-actions-focus:a')),
    );
    expect(actionsFocus.focusNode!.hasFocus, isTrue);
    expect(controller.baseline['a']?.updatedAt, DateTime.utc(2026, 1, 1, 0, 2));
    expect(controller.drafts['a']?.role, 'ADMINISTRATOR');
  });
}
