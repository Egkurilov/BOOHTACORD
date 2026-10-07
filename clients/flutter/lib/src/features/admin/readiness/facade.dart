import '../../../core/http/facade_base.dart';
import 'api.dart';
import 'model.dart';

mixin AdminReadinessFacade on ApiFacadeBase {
  late final _adminReadiness = AdminReadinessApi(transport);

  Future<AdminReadiness> inspectAdminReadiness() =>
      transport.run(_adminReadiness.inspect);
}
