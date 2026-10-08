import '../native_bindings.dart';

Color workspaceVoiceAvatarColor(String value) {
  const colors = [
    GcColors.avatarBlue,
    GcColors.avatarGreen,
    GcColors.avatarViolet,
    GcColors.avatarOrange,
    GcColors.avatarGray,
  ];
  return colors[voiceAvatarPaletteIndex(value)];
}
