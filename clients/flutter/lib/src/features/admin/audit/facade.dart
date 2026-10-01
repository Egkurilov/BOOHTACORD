import '../../../models.dart';
import '../../../core/http/facade_base.dart';
import 'api.dart';

mixin AdminAuditFacade on ApiFacadeBase {
  late final _adminAudit = AdminAuditApi(transport);

  Future<AdminAuditPage> listAdminAudit({String? before, int limit = 100}) =>
      transport.run(
        () => _adminAudit.listAdminAudit(before: before, limit: limit),
      );
}
