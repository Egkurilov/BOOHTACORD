import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/features/admin/shell/section_tabs.dart';

import 'fixture.dart';

void main() {
  for (final width in [320.0, 360.0, 390.0, 430.0]) {
    testWidgets('all admin sections remain usable at $width px with 2x text', (
      tester,
    ) async {
      await mountAdmin(tester, size: Size(width, 844), scale: 2);
      for (final section in AdminSection.values) {
        final tab = find.byKey(ValueKey('admin-section-tab-${section.name}'));
        await tester.ensureVisible(tab);
        await tester.tap(tab);
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.takeException(), isNull, reason: section.name);
      }
    });
  }

  for (final width in [390.0, 600.0, 1440.0]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets(
        'all actual admin sections remain usable at width $width / scale $scale',
        (tester) async {
          await mountAdmin(tester, size: Size(width, 900), scale: scale);
          for (final section in AdminSection.values) {
            final tab = find.byKey(
              ValueKey('admin-section-tab-${section.name}'),
            );
            await tester.ensureVisible(tab);
            await tester.tap(tab);
            await tester.pump(const Duration(milliseconds: 400));
            expect(tester.takeException(), isNull, reason: section.name);
          }
        },
      );
    }
  }
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'all admin sections fit the keyboard viewport at scale $scale',
      (tester) async {
        await mountAdmin(
          tester,
          scale: scale,
          insets: const EdgeInsets.only(bottom: 300),
        );
        for (final section in AdminSection.values) {
          final tab = find.byKey(ValueKey('admin-section-tab-${section.name}'));
          await tester.ensureVisible(tab);
          await tester.tap(tab);
          await tester.pump(const Duration(milliseconds: 400));
          expect(tester.takeException(), isNull, reason: section.name);
        }
      },
    );
  }
  testWidgets('shell chrome respects actual mobile safe insets', (
    tester,
  ) async {
    await mountAdmin(
      tester,
      padding: const EdgeInsets.only(top: 32, bottom: 34),
    );
    final header = tester.getRect(
      find.byKey(const ValueKey('admin-workspace-header')),
    );
    expect(header.top, greaterThanOrEqualTo(32));
    final panel = tester.getRect(
      find.byKey(const ValueKey('admin-content-panel')),
    );
    expect(panel.bottom, lessThanOrEqualTo(844 - 34));
  });
}
