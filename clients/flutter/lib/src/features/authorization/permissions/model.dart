enum GuildPermission {
  textCreate('channel.text.create'),
  textDelete('channel.text.delete'),
  voiceCreate('channel.voice.create'),
  voiceDelete('channel.voice.delete'),
  categoryCreate('category.create'),
  categoryDelete('category.delete');

  const GuildPermission(this.wireName);
  final String wireName;
}

enum GuildRole { member, administrator }

class PermissionSnapshot {
  const PermissionSnapshot({required this.accountId, required this.role, required this.revision, required this.values});
  final String accountId;
  final GuildRole role;
  final int revision;
  final Map<GuildPermission, bool> values;
  bool allows(GuildPermission permission) => values[permission] ?? false;

  factory PermissionSnapshot.fromJson(Map<String, dynamic> json) {
    if (json['account_id'] is! String || (json['role'] != 'MEMBER' && json['role'] != 'ADMINISTRATOR') || json['permissions_revision'] is! int || (json['permissions_revision'] as int) < 1) {
      throw const FormatException('Некорректные разрешения.');
    }
    return PermissionSnapshot(accountId: json['account_id'] as String, role: json['role'] == 'MEMBER' ? GuildRole.member : GuildRole.administrator, revision: json['permissions_revision'] as int, values: parsePermissionValues(json['permissions']));
  }
}

Map<GuildPermission, bool> parsePermissionValues(dynamic raw) {
  if (raw is! Map<String, dynamic> || raw.length != GuildPermission.values.length) throw const FormatException('Некорректные разрешения.');
  final values = <GuildPermission, bool>{};
  for (final permission in GuildPermission.values) {
    final value = raw[permission.wireName];
    if (value is! bool) throw const FormatException('Некорректные разрешения.');
    values[permission] = value;
  }
  return values;
}
