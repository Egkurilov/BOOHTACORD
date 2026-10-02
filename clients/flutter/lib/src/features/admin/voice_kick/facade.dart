import '../../../core/http/facade_base.dart';
import 'api.dart';

mixin AdminVoiceKickFacade on ApiFacadeBase {
  late final _adminVoiceKick = AdminVoiceKickApi(transport);

  Future<int> kickAdminVoiceParticipant(String accountId) =>
      transport.run(() => _adminVoiceKick.kickAdminVoiceParticipant(accountId));
}
