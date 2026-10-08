import '../native_bindings.dart';

Color workspaceSearchAvatarForeground(String identity) => const [
  Color(0xFFA5F2F0),
  Color(0xFFFFD5A8),
  Color(0xFFE3DCFF),
  Color(0xFFE9CBFF),
  Color(0xFFF4F5FA),
][voiceAvatarPaletteIndex(identity)];
