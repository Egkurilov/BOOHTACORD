import 'package:flutter/material.dart';

abstract final class GcColors {
  static const canvas = Color(0xFF0E1117);
  static const sidebar = Color(0xFF141922);
  static const content = Color(0xFF151A23);
  static const aside = Color(0xFF141922);
  static const surface = Color(0xFF1D2430);
  static const raised = Color(0xFF242D3B);
  static const hover = Color(0xFF252E3D);
  static const selected = Color(0xFF293345);
  static const text = Color(0xFFF1F4F9);
  static const textSecondary = Color(0xFFB7C0D0);
  static const muted = Color(0xFF929EB2);
  static const disabled = Color(0xFF6F7B8F);
  static const border = Color(0xFF242D3B);
  static const control = Color(0xFF6D7C94);
  static const accent = Color(0xFF5C5FE8);
  static const accentHover = Color(0xFF5558DB);
  static const accentPressed = Color(0xFF484BBF);
  static const accentText = Color(0xFFB7BAFF);
  static const success = Color(0xFF58D5A2);
  static const successBackground = Color(0xFF19352F);
  static const warning = Color(0xFFF4BD62);
  static const warningBackground = Color(0xFF3D3020);
  static const danger = Color(0xFFFF9199);
  static const dangerBackground = Color(0xFF422830);
  static const dangerSolid = Color(0xFFB8273E);
  static const streamCanvas = Color(0xFF090B10);
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
  static const shellRadius = 14.0;
  static const headerHeight = 72.0;
  static const channelRowHeight = 42.0;
  static const userFooterHeight = 68.0;
  static const voiceDockHeight = 116.0;
  static const composerMinHeight = 56.0;
  static const composerMaxHeight = 180.0;
  static const controlSmall = 32.0;
  static const control = 40.0;
  static const controlLarge = 48.0;
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
}

ThemeData guildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: GcColors.accent,
    brightness: Brightness.dark,
    surface: GcColors.surface,
    error: GcColors.danger,
  );
  return ThemeData(
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: GcColors.canvas,
    fontFamily: 'Inter',
    dividerColor: GcColors.border,
    focusColor: GcColors.focus,
    textTheme: const TextTheme(
      bodySmall: TextStyle(fontSize: 12, height: 16 / 12),
      labelSmall: TextStyle(fontSize: 12, height: 16 / 12),
      bodyMedium: TextStyle(fontSize: 14, height: 20 / 14),
      labelMedium: TextStyle(fontSize: 13, height: 18 / 13),
      bodyLarge: TextStyle(fontSize: 15, height: 22 / 15),
      titleMedium: TextStyle(fontSize: 16, height: 24 / 16),
      titleLarge: TextStyle(fontSize: 20, height: 28 / 20),
      headlineSmall: TextStyle(fontSize: 24, height: 32 / 24),
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
