import 'package:boohtacord_desktop/src/features/admin/voice_timeout/model.dart';
import 'package:boohtacord_desktop/src/screens/admin_voice_timeout/dialog.dart';
import 'package:boohtacord_desktop/src/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'launch_fixture.dart';

class ActiveTimeoutApi extends TimeoutLaunchApi {
  @override
  Future<VoiceTimeoutState> getVoiceTimeout(String id) async =>
      VoiceTimeoutState(
        true,
        DateTime.now().toUtc().add(const Duration(hours: 1)),
        VoiceTimeoutReason.spam,
        0,
        false,
      );
}

void main() {
  for (final width in [390.0, 600.0, 1440.0]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets('Windows timeout targets $width scale $scale', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 900);
        addTearDown(tester.view.reset);
        final theme = guildTheme().copyWith(
          platform: TargetPlatform.windows,
          visualDensity: VisualDensity.compact,
        );
        expect(theme.visualDensity, VisualDensity.compact);
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
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
                    api: ActiveTimeoutApi(),
                    accountId: target,
                    displayName: 'Synthetic member',
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        Future<void> checkTarget(String label) async {
          final button = find
              .ancestor(
                of: find.text(label),
                matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
              )
              .first;
          await tester.ensureVisible(button);
          expect(
            tester.getSize(button).height,
            greaterThanOrEqualTo(44),
            reason: label,
          );
          expect(
            tester.getSize(button).width,
            greaterThanOrEqualTo(44),
            reason: label,
          );
        }

        for (final label in [
          'Ограничить голос',
          'Снять ограничение',
          'Обновить состояние',
          'Закрыть',
        ]) {
          await checkTarget(label);
        }
        await tester.ensureVisible(find.text('Ограничить голос'));
        await tester.tap(find.text('Ограничить голос'));
        await tester.pumpAndSettle();
        await checkTarget('Отмена');
        await checkTarget('Подтвердить');
        expect(tester.takeException(), isNull);
      });
    }
  }
}
