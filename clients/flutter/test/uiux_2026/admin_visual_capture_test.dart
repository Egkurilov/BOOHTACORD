import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/features/admin/shell/section_tabs.dart';
import 'package:boohtacord_desktop/src/screens/admin_screen.dart';
import 'package:boohtacord_desktop/src/theme.dart';

import '../admin_accessibility/api_fixture.dart';
import 'capture_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final profile in [
    (name: 'mobile', size: const Size(393, 852), pixelRatio: 3.0),
    (name: 'desktop', size: const Size(1440, 900), pixelRatio: 2.0),
  ]) {
    testWidgets(
      'captures production Flutter admin members/settings at ${profile.name}',
      (tester) async {
        tester.view.devicePixelRatio = profile.pixelRatio;
        tester.view.physicalSize = Size(
          profile.size.width * profile.pixelRatio,
          profile.size.height * profile.pixelRatio,
        );
        addTearDown(tester.view.reset);
        await loadUiuxVisualCaptureFonts();

        final api = AccessibleAdminApi();
        final state = AppState(api)..topology = api.current;
        addTearDown(state.dispose);
        final captureKey = ValueKey('uiux-admin-capture-${profile.name}');
        await tester.pumpWidget(
          MaterialApp(
            theme: guildTheme(),
            home: RepaintBoundary(
              key: captureKey,
              child: Scaffold(body: AdminScreen(state: state)),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final roleLabel = find.descendant(
          of: find.byKey(const ValueKey('admin-member-role-filter')),
          matching: find.text(profile.name == 'mobile' ? 'Все' : 'Все роли'),
        );
        expect(roleLabel, findsOneWidget);
        final roleText = tester.widget<Text>(roleLabel);
        expect(
          roleText.style?.fontFamily ??
              DefaultTextStyle.of(tester.element(roleLabel)).style.fontFamily,
          GcTypography.fontFamily,
        );
        final statusLabel = find.descendant(
          of: find.byKey(const ValueKey('admin-member-status-filter')),
          matching: find.text(
            profile.name == 'mobile' ? 'Любой' : 'Любой статус',
          ),
        );
        expect(statusLabel, findsOneWidget);
        final statusText = tester.widget<Text>(statusLabel);
        expect(
          statusText.style?.fontFamily ??
              DefaultTextStyle.of(tester.element(statusLabel)).style.fontFamily,
          GcTypography.fontFamily,
        );

        for (final section in [AdminSection.members, AdminSection.guild]) {
          final tab = find.byKey(ValueKey('admin-section-tab-${section.name}'));
          await tester.ensureVisible(tab);
          await tester.tap(tab);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: section.name);
          if (section == AdminSection.members && profile.name == 'mobile') {
            expect(find.text('Роль'), findsOneWidget);
            expect(find.textContaining('Роль: long-login-'), findsNothing);
          }
          await captureUiuxBoundary(
            tester,
            find.byKey(captureKey),
            fileName:
                'flutter-admin-${section.name}-${profile.name}-${profile.size.width.toInt()}x${profile.size.height.toInt()}.png',
            pixelRatio: profile.pixelRatio,
          );
        }
      },
    );
  }
}
