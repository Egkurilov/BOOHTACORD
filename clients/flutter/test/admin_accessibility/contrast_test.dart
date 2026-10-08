import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/theme.dart';

import 'fixture.dart';

double contrast(Color foreground, Color background) {
  final high = foreground.computeLuminance(),
      low = background.computeLuminance();
  return (high + .05) / (low + .05);
}

void main() {
  testWidgets(
    'actual dark admin text and focus controls meet contrast and visible-outline thresholds',
    (tester) async {
      await mountAdmin(tester);
      for (final foreground in [
        GcColors.text,
        GcColors.textSecondary,
        GcColors.muted,
        GcColors.success,
        GcColors.danger,
      ]) {
        expect(
          contrast(foreground, GcColors.content),
          greaterThanOrEqualTo(4.5),
        );
      }
      expect(
        contrast(GcColors.onAccent, GcColors.accent),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        contrast(GcColors.focus, GcColors.surface),
        greaterThanOrEqualTo(3),
      );
      final save = find.byKey(const ValueKey('save-account:account-a'));
      await tester.ensureVisible(save);
      final theme = Theme.of(tester.element(save));
      expect(theme.brightness, Brightness.dark);
      final border = theme.filledButtonTheme.style!.side!.resolve({
        WidgetState.focused,
      })!;
      expect(border.color, GcColors.focus);
      expect(border.width, greaterThanOrEqualTo(2));
      expect(
        theme.filledButtonTheme.style!.minimumSize!.resolve({}),
        const Size(44, 44),
      );
    },
  );
}
