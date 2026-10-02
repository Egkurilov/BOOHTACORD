import 'package:flutter/material.dart';

abstract final class GcColors {
  static const canvas = Color(0xFF0E1117);
  static const sidebar = Color(0xFF141922);
  static const content = Color(0xFF151A23);
  static const aside = Color(0xFF141922);
  static const surface = Color(0xFF1D2430);
  static const input = Color(0xFF1D2430);
  static const raised = Color(0xFF242D3B);
  static const hover = Color(0xFF252E3D);
  static const selected = Color(0xFF293345);
  static const text = Color(0xFFF1F4F9);
  static const textSecondary = Color(0xFFB7C0D0);
  static const muted = Color(0xFF929EB2);
  static const disabled = Color(0xFF6F7B8F);
  static const border = Color(0xFF242D3B);
  static const borderSubtle = Color(0xFF242D3B);
  static const control = Color(0xFF6D7C94);
  static const accent = Color(0xFF5C5FE8);
  static const accentHover = Color(0xFF5558DB);
  static const accentPressed = Color(0xFF484BBF);
  static const accentText = Color(0xFFB7BAFF);
  static const onAccent = Color(0xFFFFFFFF);
  static const success = Color(0xFF58D5A2);
  static const successBackground = Color(0xFF19352F);
  static const warning = Color(0xFFF4BD62);
  static const warningBackground = Color(0xFF3D3020);
  static const danger = Color(0xFFFF9199);
  static const dangerBackground = Color(0xFF422830);
  static const dangerSolid = Color(0xFFB8273E);
  static const onDanger = Color(0xFFFFFFFF);
  static const streamCanvas = Color(0xFF090B10);
  static const overlay = Color(0xA8000000);
  static const focus = Color(0xFFADB8FF);
  static const avatarBlue = Color(0xFF365ACA);
  static const avatarGreen = Color(0xFF137C58);
  static const avatarViolet = Color(0xFF6D3DBE);
  static const avatarOrange = Color(0xFFA64C18);
  static const avatarGray = Color(0xFF556176);
}

abstract final class GcLayout {
  static const mobileBreakpoint = 1024.0;
  static const mediumBreakpoint = 1280.0;
  static const wideBreakpoint = 1440.0;

  static const navSmall = 256.0;
  static const navMedium = 264.0;
  static const navWide = 280.0;
  static const asideMedium = 240.0;
  static const asideWide = 248.0;
  static const frameInset = 16.0;
  static const frameWide = 0.0;
  static const shellRadius = 14.0;
  static const headerHeight = 72.0;
  static const channelRowHeight = 42.0;
  static const voiceMemberRowHeight = 24.0;
  static const userFooterHeight = 68.0;
  static const voiceDockHeight = 116.0;
  static const composerMinHeight = 56.0;
  static const composerMaxHeight = 180.0;
  static const controlSmall = 32.0;
  static const control = 40.0;
  static const controlLarge = 48.0;
  static const iconSize = 20.0;
  static const iconLarge = 24.0;
}

abstract final class GcSpacing {
  static const x1 = 4.0;
  static const x2 = 8.0;
  static const x3 = 12.0;
  static const x4 = 16.0;
  static const x5 = 20.0;
  static const x6 = 24.0;
  static const x8 = 32.0;
  static const x10 = 40.0;
  static const x12 = 48.0;
  static const x16 = 64.0;
}

abstract final class GcRadii {
  static const xs = 4.0;
  static const sm = 6.0;
  static const md = 10.0;
  static const lg = 14.0;
  static const shell = 20.0;
  static const full = 999.0;
}

abstract final class GcTypography {
  static const fontFamily = 'Inter';
  static const fontMonoFamily = 'monospace';

  static const caption = 12.0;
  static const small = 13.0;
  static const body = 14.0;
  static const message = 15.0;
  static const title = 16.0;
  static const section = 20.0;
  static const page = 24.0;

  static const captionLine = 16.0;
  static const smallLine = 18.0;
  static const bodyLine = 20.0;
  static const messageLine = 22.0;
  static const titleLine = 24.0;
  static const sectionLine = 28.0;
  static const pageLine = 32.0;

  static const regular = FontWeight.w400;
  static const medium = FontWeight.w500;
  static const semibold = FontWeight.w600;
  static const bold = FontWeight.w700;
}

abstract final class GcMotion {
  static const fast = Duration(milliseconds: 120);
  static const base = Duration(milliseconds: 180);
  static const slow = Duration(milliseconds: 240);
  static const standardCurve = Cubic(0.2, 0, 0, 1);
}

abstract final class GcShadows {
  static const popup = BoxShadow(
    color: Color(0x40000000),
    offset: Offset(0, 12),
    blurRadius: 36,
  );
  static const shell = BoxShadow(
    color: Color(0x24000000),
    offset: Offset(0, 20),
    blurRadius: 70,
  );
}

ThemeData guildTheme() {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: GcColors.accent,
        brightness: Brightness.dark,
        surface: GcColors.surface,
        error: GcColors.danger,
      ).copyWith(
        primary: GcColors.accent,
        onPrimary: GcColors.onAccent,
        primaryContainer: GcColors.selected,
        onPrimaryContainer: GcColors.accentText,
        secondary: GcColors.accentText,
        onSecondary: GcColors.canvas,
        secondaryContainer: GcColors.raised,
        onSecondaryContainer: GcColors.text,
        tertiary: GcColors.success,
        onTertiary: GcColors.canvas,
        tertiaryContainer: GcColors.successBackground,
        onTertiaryContainer: GcColors.success,
        surface: GcColors.surface,
        onSurface: GcColors.text,
        surfaceTint: GcColors.surface,
        error: GcColors.danger,
        onError: GcColors.onDanger,
        errorContainer: GcColors.dangerBackground,
        onErrorContainer: GcColors.danger,
        outline: GcColors.control,
        outlineVariant: GcColors.borderSubtle,
        surfaceContainerLowest: GcColors.canvas,
        surfaceContainerLow: GcColors.content,
        surfaceContainer: GcColors.surface,
        surfaceContainerHigh: GcColors.raised,
        surfaceContainerHighest: GcColors.hover,
      );
  return ThemeData(
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: GcColors.canvas,
    fontFamily: GcTypography.fontFamily,
    dividerColor: GcColors.border,
    focusColor: GcColors.focus,
    textTheme: const TextTheme(
      bodySmall: TextStyle(
        fontSize: GcTypography.caption,
        height: GcTypography.captionLine / GcTypography.caption,
      ),
      labelSmall: TextStyle(
        fontSize: GcTypography.caption,
        height: GcTypography.captionLine / GcTypography.caption,
      ),
      bodyMedium: TextStyle(
        fontSize: GcTypography.body,
        height: GcTypography.bodyLine / GcTypography.body,
      ),
      labelMedium: TextStyle(
        fontSize: GcTypography.small,
        height: GcTypography.smallLine / GcTypography.small,
      ),
      bodyLarge: TextStyle(
        fontSize: GcTypography.message,
        height: GcTypography.messageLine / GcTypography.message,
      ),
      titleMedium: TextStyle(
        fontSize: GcTypography.title,
        height: GcTypography.titleLine / GcTypography.title,
      ),
      titleLarge: TextStyle(
        fontSize: GcTypography.section,
        height: GcTypography.sectionLine / GcTypography.section,
      ),
      headlineSmall: TextStyle(
        fontSize: GcTypography.page,
        height: GcTypography.pageLine / GcTypography.page,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: GcColors.surface,
      hintStyle: const TextStyle(color: GcColors.muted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(GcRadii.sm)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(GcRadii.sm)),
        borderSide: const BorderSide(color: GcColors.control),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(GcRadii.sm)),
        borderSide: BorderSide(color: GcColors.focus, width: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: GcColors.accent,
        disabledBackgroundColor: GcColors.surface,
        disabledForegroundColor: GcColors.disabled,
        foregroundColor: Colors.white,
        minimumSize: const Size(GcLayout.control, GcLayout.control),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(GcRadii.md),
        ),
      ),
    ),
  );
}
