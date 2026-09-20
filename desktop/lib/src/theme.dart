import 'package:flutter/material.dart';

abstract final class GcColors {
  static const canvas = Color(0xFF0E1117);
  static const sidebar = Color(0xFF141922);
  static const content = Color(0xFF151A23);
  static const surface = Color(0xFF1D2430);
  static const raised = Color(0xFF242D3B);
  static const hover = Color(0xFF252E3D);
  static const selected = Color(0xFF293345);
  static const text = Color(0xFFF1F4F9);
  static const textSecondary = Color(0xFFB7C0D0);
  static const muted = Color(0xFF929EB2);
  static const border = Color(0xFF242D3B);
  static const control = Color(0xFF6D7C94);
  static const accent = Color(0xFF5C5FE8);
  static const accentText = Color(0xFFB7BAFF);
  static const success = Color(0xFF58D5A2);
  static const warning = Color(0xFFF4BD62);
  static const danger = Color(0xFFFF9199);
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
    focusColor: const Color(0xFFADB8FF),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: GcColors.surface,
      hintStyle: const TextStyle(color: GcColors.muted),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: GcColors.control),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFADB8FF), width: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: GcColors.accent,
        foregroundColor: Colors.white,
        minimumSize: const Size(40, 44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
  );
}
