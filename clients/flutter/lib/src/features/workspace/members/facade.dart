import '../../../models.dart';
import '../../../core/http/facade_base.dart';
import 'api.dart';

mixin MembersFacade on ApiFacadeBase {
  late final _members = MembersApi(transport);

  Future<List<GuildMember>> members() =>
      transport.run(() => _members.members());

  Future<GuildMember> memberProfile(String accountId) =>
      transport.run(() => _members.memberProfile(accountId));
}
