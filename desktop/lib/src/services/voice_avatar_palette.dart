int voiceAvatarPaletteIndex(String identity) {
  var hash = 2166136261;
  for (final codeUnit in identity.codeUnits) {
    hash = ((hash ^ codeUnit) * 16777619) & 0xffffffff;
  }
  return hash % 5;
}
