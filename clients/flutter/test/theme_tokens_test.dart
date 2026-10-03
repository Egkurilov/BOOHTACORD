import 'package:boohtacord_desktop/src/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('matches the canonical Design V2 semantic palette', () {
    expect(GcColors.canvas, const Color(0xFF0B0D12));
    expect(GcColors.sidebar, const Color(0xFF11131A));
    expect(GcColors.content, const Color(0xFF171A22));
    expect(GcColors.aside, const Color(0xFF11131A));
    expect(GcColors.surface, const Color(0xFF1A1D26));
    expect(GcColors.input, const Color(0xFF1A1D26));
    expect(GcColors.raised, const Color(0xFF222631));
    expect(GcColors.hover, const Color(0xFF272C39));
    expect(GcColors.selected, const Color(0xFF2B3040));
    expect(GcColors.text, const Color(0xFFF4F5FA));
    expect(GcColors.textSecondary, const Color(0xFFB6BDCE));
    expect(GcColors.muted, const Color(0xFFA0A9BE));
    expect(GcColors.disabled, const Color(0xFF6F7B8F));
    expect(GcColors.borderSubtle, const Color(0xFF2A2F3A));
    expect(GcColors.control, const Color(0xFF707B91));
    expect(GcColors.accent, const Color(0xFF5865F2));
    expect(GcColors.accentHover, const Color(0xFF4752C4));
    expect(GcColors.accentPressed, const Color(0xFF484BBF));
    expect(GcColors.accentText, const Color(0xFFACAEFF));
    expect(GcColors.brandAccent, const Color(0xFF7C3AED));
    expect(GcColors.voice, const Color(0xFF06B6D4));
    expect(GcColors.stream, const Color(0xFFEC4899));
    expect(GcColors.success, const Color(0xFF22C55E));
    expect(GcColors.successBackground, const Color(0xFF19352F));
    expect(GcColors.warning, const Color(0xFFF59E0B));
    expect(GcColors.warningBackground, const Color(0xFF3D3020));
    expect(GcColors.danger, const Color(0xFFEF4444));
    expect(GcColors.dangerBackground, const Color(0xFF2B1116));
    expect(GcColors.dangerSolid, const Color(0xFFB91C1C));
    expect(GcColors.streamCanvas, const Color(0xFF090B10));
    expect(GcColors.overlay, const Color(0xC204060A));
    expect(GcColors.focus, const Color(0xFFB4A4FF));
    expect(GcColors.avatarBlue, const Color(0xFF17464A));
    expect(GcColors.avatarGreen, const Color(0xFF553521));
    expect(GcColors.avatarViolet, const Color(0xFF393059));
    expect(GcColors.avatarOrange, const Color(0xFF423657));
    expect(GcColors.avatarGray, const Color(0xFF556176));
  });

  test('matches canonical Design V2 layout and radii', () {
    expect(GcLayout.navSmall, 280);
    expect(GcLayout.navMedium, 280);
    expect(GcLayout.navWide, 280);
    expect(GcLayout.asideMedium, 248);
    expect(GcLayout.asideWide, 248);
    expect(GcLayout.frameMedium, 0);
    expect(GcLayout.frameWide, 0);
    expect(GcLayout.shellRadius, 16);
    expect(GcLayout.headerHeight, 64);
    expect(GcLayout.headerMobileHeight, 56);
    expect(GcLayout.channelRowHeight, 36);
    expect(GcLayout.voiceMemberRowHeight, 24);
    expect(GcLayout.userFooterHeight, 64);
    expect(GcLayout.voiceDockHeight, 112);
    expect(GcLayout.composerMinHeight, 56);
    expect(GcLayout.composerMaxHeight, 180);
    expect(GcLayout.controlSmall, 32);
    expect(GcLayout.control, 36);
    expect(GcLayout.controlLarge, 48);
    expect(GcLayout.fieldHeight, 44);
    expect(GcLayout.touchTargetSize, 44);
    expect(GcLayout.authTabHeight, 40);
    expect(GcLayout.iconSize, 20);
    expect(GcLayout.iconLarge, 24);
    expect(GcRadii.xs, 4);
    expect(GcRadii.sm, 6);
    expect(GcRadii.md, 8);
    expect(GcRadii.lg, 12);
    expect(GcRadii.shell, 16);
    expect(GcRadii.full, 999);
  });

  test('mirrors web semantic colors and missing layout tokens', () {
    expect(GcColors.input, GcColors.surface);
    expect(GcColors.borderSubtle, GcColors.border);
    expect(GcColors.onAccent, Colors.white);
    expect(GcColors.onDanger, Colors.white);
    expect(GcColors.overlay, const Color(0xC204060A));
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
