import '../../../models.dart';
import '../../../core/http/facade_base.dart';
import 'api.dart';

mixin AdminAccountsFacade on ApiFacadeBase {
  late final _adminAccounts = AdminAccountsApi(transport);

  Future<AdminAccountPage> listAdminAccounts({
    String? cursor,
    int limit = 100,
  }) => transport.run(
    () => _adminAccounts.listAdminAccounts(cursor: cursor, limit: limit),
  );

  Future<void> updateAdminAccount({
    required String accountId,
    required String role,
    required bool blocked,
  }) => transport.run(
    () => _adminAccounts.updateAdminAccount(
      accountId: accountId,
      role: role,
      blocked: blocked,
    ),
  );
}
