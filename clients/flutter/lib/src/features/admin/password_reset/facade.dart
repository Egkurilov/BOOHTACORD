import '../../../models.dart';
import '../../../core/http/facade_base.dart';
import 'api.dart';

mixin AdminPasswordResetFacade on ApiFacadeBase {
  late final _adminPasswordReset = AdminPasswordResetApi(transport);

  Future<AdminPasswordResetLink> createAdminPasswordResetLink(
    String accountId,
  ) => transport.run(
    () => _adminPasswordReset.createAdminPasswordResetLink(accountId),
  );
}
