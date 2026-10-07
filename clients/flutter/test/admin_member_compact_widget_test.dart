import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:boohtacord_desktop/src/screens/admin_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'admin_topology_fake_api.dart';

void main() {
  testWidgets('compact member directory matches web typography and targets', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    var navigationToggled = false;
    var closed = false;
    final api = TopologyTestApi()
      ..accounts = [
        AdminAccount(
          accountId: 'member-1',
          login: 'member',
          displayName: 'Member Name',
          role: 'MEMBER',
          blocked: false,
          createdAt: DateTime.utc(2026, 10, 1),
        ),
      ];
    final state = AppState(api)..topology = api.current;
    addTearDown(state.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminScreen(
            state: state,
            onToggleNavigation: () => navigationToggled = true,
            onClose: () => closed = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final title = tester.getSemantics(
      find.byKey(const ValueKey('admin-screen-title')),
    );
    expect(title.getSemanticsData().label, 'Администрирование');
    expect(title.getSemanticsData().flagsCollection.isHeader, isTrue);
    final section = tester.widget<Text>(
      find.byKey(const ValueKey('admin-members-section-title')),
    );
    expect(section.style?.fontSize, 20);
    expect(section.style?.height, 28 / 20);
    expect(section.style?.fontWeight, FontWeight.w600);
    final account = tester.widget<Text>(find.text('Member Name'));
    expect(account.style?.fontSize, 16);
    expect(account.style?.height, 20 / 16);
    expect(account.style?.fontWeight, FontWeight.w600);
    expect(
      tester.getSize(find.byKey(const ValueKey('admin-workspace-nav-toggle'))),
      const Size(44, 44),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('admin-workspace-close'))),
      const Size(44, 44),
    );
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const ValueKey('admin-workspace-nav-toggle')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('admin-workspace-close')));
    await tester.pump();
    expect(navigationToggled, isTrue);
    expect(closed, isTrue);
  });
}
