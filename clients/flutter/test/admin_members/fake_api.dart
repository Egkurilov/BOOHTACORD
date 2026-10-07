import 'package:boohtacord_desktop/src/models.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';

export 'package:boohtacord_desktop/src/models.dart';

class MembersApiFake extends ApiClient {
  final pages = <String?, AdminAccountPage>{};
  final cursors = <String?>[];
  final expectedTimestamps = <DateTime?>[];
  final kickedAccounts = <String>[];
  Future<void> Function(String, String, bool, DateTime?)? onSave;

  @override
  Future<AdminAccountPage> listAdminAccounts({String? cursor, int limit = 100}) async {
    cursors.add(cursor);
    return pages[cursor] ?? const AdminAccountPage(accounts: []);
  }

  @override
  Future<void> updateAdminAccount({
    required String accountId,
    required String role,
    required bool blocked,
    DateTime? expectedUpdatedAt,
  }) async {
    expectedTimestamps.add(expectedUpdatedAt);
    await onSave?.call(accountId, role, blocked, expectedUpdatedAt);
  }

  @override
  Future<int> kickAdminVoiceParticipant(String accountId) async {
    kickedAccounts.add(accountId);
    return 1;
  }
}

AdminAccount member(
  String id, {
  String role = 'MEMBER',
  bool blocked = false,
  int version = 1,
}) => AdminAccount(
  accountId: id,
  login: 'user-$id',
  displayName: 'User $id',
  role: role,
  blocked: blocked,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026, 1, 1, 0, version),
);
