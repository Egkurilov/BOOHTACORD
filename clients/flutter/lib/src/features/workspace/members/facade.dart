import '../../../models.dart';
import '../../../core/http/facade_base.dart';
import 'api.dart';

mixin MembersFacade on ApiFacadeBase {
  late final _members = MembersApi(transport);

  Future<List<GuildMember>> members() => _members.members();

  Future<GuildMember> memberProfile(String accountId) =>
      _members.memberProfile(accountId);
}
