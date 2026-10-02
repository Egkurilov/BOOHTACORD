import 'package:flutter/material.dart';

import '../theme.dart';

int voiceAvatarPaletteIndex(String identity) {
  var hash = 2166136261;
  for (final codeUnit in identity.codeUnits) {
    hash = ((hash ^ codeUnit) * 16777619) & 0xffffffff;
  }
  return hash % 5;
}

Color voiceAvatarColor(String identity) {
  const colors = [
    GcColors.avatarBlue,
    GcColors.avatarGreen,
    GcColors.avatarViolet,
    GcColors.avatarOrange,
    GcColors.avatarGray,
  ];
  return colors[voiceAvatarPaletteIndex(identity)];
}
