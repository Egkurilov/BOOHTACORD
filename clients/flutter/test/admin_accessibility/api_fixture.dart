import 'dart:async';

import 'package:boohtacord_desktop/src/models.dart';
import 'package:boohtacord_desktop/src/features/admin/guild_settings/model.dart';
import 'package:boohtacord_desktop/src/features/admin/role_permissions/model.dart';
import 'package:boohtacord_desktop/src/features/authorization/permissions/model.dart';

import '../admin_topology_fake_api.dart';

class AccessibleAdminApi extends TopologyTestApi {
  AccessibleAdminApi() {
    accounts = [
      AdminAccount(
        accountId: 'account-a',
        login: 'long-login-' * 12,
        displayName: 'Длинное имя участника ' * 12,
        role: 'MEMBER',
        blocked: false,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    ];
  }
  Completer<void>? pendingSave;
  Completer<void>? pendingRoleSave;
  Completer<GuildSettings>? pendingGuild;
  Object? roleSaveFailure;
  @override
  Future<void> saveMemberRolePolicy({
    required int revision,
    required Map<GuildPermission, bool> values,
    required bool confirmDeleteGrants,
  }) async {
    if (roleSaveFailure case final failure?) throw failure;
    await pendingRoleSave?.future;
  }

  @override
  Future<void> updateAdminAccount({
    required String accountId,
    required String role,
    required bool blocked,
    DateTime? expectedUpdatedAt,
  }) => pendingSave?.future ?? Future.value();
  @override
  Future<AdminPasswordResetLink> createAdminPasswordResetLink(
    String accountId,
  ) async => AdminPasswordResetLink(
    url: 'https://example.invalid/reset/fixture-only',
    expiresAt: DateTime(2026, 10, 10),
  );
  @override
  Future<GuildSettings> readGuildSettings() =>
      pendingGuild?.future ??
      Future.value(const GuildSettings('Гильдия', 1, null));
  @override
  Future<RolePolicyPage> loadRolePolicies() async => RolePolicyPage(1, [
    for (final role in GuildRole.values)
      RolePolicy(
        role: role,
        displayName: role == GuildRole.member
            ? 'Пользователь'
            : 'Администратор',
        editable: role == GuildRole.member,
        permissions: {
          for (final permission in GuildPermission.values) permission: false,
        },
      ),
  ]);
}
