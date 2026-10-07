import 'package:boohtacord_desktop/src/features/admin/members/controller.dart';
import 'package:boohtacord_desktop/src/features/admin/members/panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_api.dart';

void main() {
  testWidgets('voice kick is offered only for another active voice member', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = MembersApiFake()..pages[null] = AdminAccountPage(accounts: [member('peer'), member('self')]);
    final controller = AdminMembersController(api);
    addTearDown(controller.dispose);
    await controller.load();
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: AdminMembersPanel(
      controller: controller, currentAccountId: 'self', voiceParticipantIds: const {'peer', 'self'},
    ))));
    await tester.tap(find.byKey(const ValueKey('admin-member-actions:peer')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Отключить от голоса'));
    await tester.pumpAndSettle();
    expect(find.text('Отключить от голоса?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Отключить'));
    await tester.pumpAndSettle();
    expect(api.kickedAccounts, ['peer']);
    await tester.tap(find.byKey(const ValueKey('admin-member-actions:self')));
    await tester.pumpAndSettle();
    expect(find.text('Отключить от голоса'), findsNothing);
  });
}
