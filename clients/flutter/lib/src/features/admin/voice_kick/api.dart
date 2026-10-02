import '../../../core/http/api_failure.dart';
import '../../../core/http/transport.dart';

class AdminVoiceKickApi {
  AdminVoiceKickApi(this.transport);
  final ApiTransport transport;

  Future<int> kickAdminVoiceParticipant(String accountId) async {
    if (accountId.isEmpty) {
      throw const ApiFailure('Выберите участника для отключения от голоса.');
    }
    final data = await transport.checked(
      await transport.client.post(
        transport.uri(
          '/admin/accounts/${Uri.encodeComponent(accountId)}/voice-kick',
        ),
        headers: await transport.headers(),
      ),
    ) as Map<String, dynamic>;
    final revokedLeases = data['revoked_leases'];
    if (revokedLeases is! int || revokedLeases < 0) {
      throw const ApiFailure(
        'Сервер вернул некорректный результат отключения.',
      );
    }
    return revokedLeases;
  }
}
