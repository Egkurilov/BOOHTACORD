import '../../models.dart';
import '../../guild_presence_state.dart';
import '../../features/workspace/lifecycle/controller.dart';
import '../composition/owners.dart';

mixin AppMembersAccess on AppOwners {
  List<GuildMember> get members => workspace.members;

  set members(List<GuildMember> value) => workspace.members = value;

  GuildPresenceState get guildPresence => workspace.guildPresence;

  bool get membersLoading => workspace.membersLoading;

  set membersLoading(bool value) => workspace.membersLoading = value;

  String? get membersError => workspace.membersError;

  set membersError(String? value) => workspace.membersError = value;

  Future<void> refreshMembers() => workspace.refreshMembers();

  MemberPresence memberPresence(GuildMember member) =>
      workspace.memberPresence(member);
}
