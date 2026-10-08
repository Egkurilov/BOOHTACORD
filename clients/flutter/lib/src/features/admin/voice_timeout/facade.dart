import '../../../core/http/facade_base.dart';
import 'api.dart';
import 'model.dart';

mixin AdminVoiceTimeoutFacade on ApiFacadeBase {
  late final _voiceTimeout = AdminVoiceTimeoutApi(transport);
  Future<VoiceTimeoutState> getVoiceTimeout(String account) =>
      _voiceTimeout.request(account, 'GET');
  Future<VoiceTimeoutState> setVoiceTimeout(
    String account,
    VoiceTimeoutInput input,
  ) => _voiceTimeout.request(account, 'PUT', input: input);
  Future<VoiceTimeoutState> clearVoiceTimeout(String account) =>
      _voiceTimeout.request(account, 'DELETE');
}
