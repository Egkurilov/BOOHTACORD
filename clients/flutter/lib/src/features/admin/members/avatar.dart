import 'package:flutter/material.dart';

import '../../../models.dart';
import '../../../theme.dart';

({Color background, Color foreground}) adminMemberAvatarColors(String id) {
  const backgrounds = [
    GcColors.avatarBlue,
    GcColors.avatarGreen,
    GcColors.avatarViolet,
    GcColors.avatarOrange,
    GcColors.avatarGray,
  ];
  const foregrounds = [
    Color(0xFFA5F2F0),
    Color(0xFFFFD5A8),
    Color(0xFFE3DCFF),
    Color(0xFFE9CBFF),
    Color(0xFFF4F5FA),
  ];
  var hash = 2166136261;
  for (final rune in id.runes) {
    final unit = rune <= 0xFFFF ? rune : 0xD800 + ((rune - 0x10000) >> 10);
    hash = ((hash ^ unit) * 16777619) & 0xFFFFFFFF;
  }
  final index = hash % backgrounds.length;
  return (background: backgrounds[index], foreground: foregrounds[index]);
}

String adminMemberInitials(String? name, {String fallback = 'У'}) =>
    RegExp(r'\p{L}', unicode: true)
        .allMatches(name ?? '')
        .take(2)
        .map((match) => match.group(0)!)
        .join()
        .toUpperCase()
        .ifEmpty(fallback);

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}

class AdminMemberAvatar extends StatelessWidget {
  const AdminMemberAvatar({super.key, required this.account, this.size = 36});
  final AdminAccount account;
  final double size;
  @override
  Widget build(BuildContext context) {
    final colors = adminMemberAvatarColors(account.accountId);
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: colors.background,
      child: Text(
        adminMemberInitials(account.displayName),
        style: TextStyle(color: colors.foreground, fontSize: 12),
      ),
    );
  }
}
