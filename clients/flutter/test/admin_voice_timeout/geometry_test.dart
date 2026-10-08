import 'package:boohtacord_desktop/src/screens/admin_voice_timeout/dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'launch_fixture.dart';

void main() {
  for (final width in [390.0, 600.0, 1440.0]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets('timeout route $width scale $scale with keyboard', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 900);
        addTearDown(tester.view.reset);
        final api = TimeoutLaunchApi();
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(scale),
                viewInsets: const EdgeInsets.only(bottom: 300),
                disableAnimations: true,
              ),
              child: child!,
            ),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showAdminVoiceTimeout(
                    context,
                    api: api,
                    accountId: target,
                    displayName: 'Synthetic member with a long display name',
                  ),
                  child: const Text('Open timeout'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open timeout'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final apply = find.text('Ограничить голос');
        await tester.ensureVisible(apply);
        await tester.tap(apply);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text('Отмена'));
        await tester.tap(find.text('Отмена'));
        await tester.pumpAndSettle();
        expect(api.reads, 1);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
