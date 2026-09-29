import 'package:boohtacord_desktop/src/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mirrors web semantic colors and missing layout tokens', () {
    expect(GcColors.input, GcColors.surface);
    expect(GcColors.borderSubtle, GcColors.border);
    expect(GcColors.onAccent, Colors.white);
    expect(GcColors.onDanger, Colors.white);
    expect(GcColors.overlay, const Color(0xA8000000));
    expect(GcLayout.frameWide, 0);
    expect(GcLayout.voiceMemberRowHeight, 24);
    expect(GcLayout.iconSize, 20);
    expect(GcLayout.iconLarge, 24);
    expect(GcRadii.full, 999);
  });

  test(
    'uses the web typography scale and line heights in Material defaults',
    () {
      final theme = guildTheme();
      expect(GcTypography.fontFamily, 'Inter');
      expect(theme.textTheme.bodySmall?.fontSize, 12);
      expect(theme.textTheme.bodySmall?.height, 16 / 12);
      expect(theme.textTheme.labelMedium?.fontSize, 13);
      expect(theme.textTheme.labelMedium?.height, 18 / 13);
      expect(theme.textTheme.bodyMedium?.fontSize, 14);
      expect(theme.textTheme.bodyMedium?.height, 20 / 14);
      expect(theme.textTheme.bodyLarge?.fontSize, 15);
      expect(theme.textTheme.bodyLarge?.height, 22 / 15);
      expect(theme.textTheme.titleMedium?.fontSize, 16);
      expect(theme.textTheme.titleLarge?.fontSize, 20);
      expect(theme.textTheme.headlineSmall?.fontSize, 24);
      expect(theme.colorScheme.primary, GcColors.accent);
      expect(theme.colorScheme.onPrimary, GcColors.onAccent);
      expect(theme.colorScheme.primaryContainer, GcColors.selected);
      expect(theme.colorScheme.onSurface, GcColors.text);
      expect(theme.colorScheme.error, GcColors.danger);
      expect(theme.colorScheme.outline, GcColors.control);
      expect(theme.colorScheme.surfaceContainerHigh, GcColors.raised);
    },
  );

  test('mirrors web motion and elevation tokens', () {
    expect(GcMotion.fast, const Duration(milliseconds: 120));
    expect(GcMotion.base, const Duration(milliseconds: 180));
    expect(GcMotion.slow, const Duration(milliseconds: 240));
    expect(GcMotion.standardCurve, const Cubic(0.2, 0, 0, 1));
    expect(GcShadows.popup.offset, const Offset(0, 12));
    expect(GcShadows.popup.blurRadius, 36);
    expect(GcShadows.popup.color, const Color(0x40000000));
    expect(GcShadows.shell.offset, const Offset(0, 20));
    expect(GcShadows.shell.blurRadius, 70);
    expect(GcShadows.shell.color, const Color(0x24000000));
  });
}
