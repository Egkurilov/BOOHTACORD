import '../../../models.dart';
import '../../../core/http/api_failure.dart';
import '../../../core/http/transport.dart';
import '../../profile/revision/cache.dart';
import '../../profile/revision/avatar_url.dart';

class MembersApi {
  MembersApi(this.transport);
  final ApiTransport transport;

  Future<List<GuildMember>> members() async {
    final result = <GuildMember>[];
    String? cursor;
    do {
      final data = await transport.checked(
        await transport.client.get(
          transport.uri('/members', {'limit': '100', 'cursor': ?cursor}),
          headers: await transport.headers(),
        ),
      ) as Map<String, dynamic>;
      result.addAll(
        (data['members'] as List<dynamic>).map(
          (value) => _member(value as Map<String, dynamic>),
        ),
      );
      cursor = data['next_cursor'] as String?;
    } while (cursor != null);
    return result;
  }

  Future<GuildMember> memberProfile(String accountId) async {
    if (accountId.isEmpty) {
      throw const ApiFailure('Не выбран участник гильдии.');
    }
    final data = await transport.checked(
      await transport.client.get(
        transport.uri('/members/${Uri.encodeComponent(accountId)}'),
        headers: await transport.headers(),
      ),
    );
    if (data is! Map<String, dynamic>) {
      throw const ApiFailure('Сервер вернул некорректные данные участника.');
    }
    return _member(data);
  }

  GuildMember _member(Map<String, dynamic> data) {
    final revision = data['profile_revision'];
    if (revision != null) {
      if (revision is! int || revision <= 0) {
        throw const FormatException('Invalid profile revision.');
      }
    }
    final member = GuildMember.fromJson(
      withAvatarRevision(data, revision as int?),
    );
    if (revision != null) {
      memberProfileRevisions.recordMember(member, revision);
    }
    return member;
  }
}
