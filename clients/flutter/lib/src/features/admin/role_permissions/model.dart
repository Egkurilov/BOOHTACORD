import '../../authorization/permissions/model.dart';

class RolePolicy {
  const RolePolicy({
    required this.role,
    required this.displayName,
    required this.editable,
    required this.permissions,
  });
  final GuildRole role;
  final String displayName;
  final bool editable;
  final Map<GuildPermission, bool> permissions;
  factory RolePolicy.fromJson(Map<String, dynamic> json) {
    if ((json['role'] != 'MEMBER' && json['role'] != 'ADMINISTRATOR') ||
        json['display_name'] is! String ||
        json['editable'] is! bool) {
      throw const FormatException('Некорректная роль.');
    }
    return RolePolicy(
      role: json['role'] == 'MEMBER'
          ? GuildRole.member
          : GuildRole.administrator,
      displayName: json['display_name'] as String,
      editable: json['editable'] as bool,
      permissions: parsePermissionValues(json['permissions']),
    );
  }
}

class RolePolicyPage {
  const RolePolicyPage(this.revision, this.roles);
  final int revision;
  final List<RolePolicy> roles;
}
