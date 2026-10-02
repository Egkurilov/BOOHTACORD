import '../../../models.dart';
import '../lifecycle/controller.dart';

extension WorkspaceMembers on WorkspaceController {
  Future<void> refreshMembers() async {
    final ticket = scope.capture();
    if (!accepts(ticket)) return;
    membersLoading = true;
    membersError = null;
    changed();
    try {
      final result = await api.members();
      if (accepts(ticket)) members = result;
    } catch (cause) {
      if (accepts(ticket)) membersError = effects.message(cause);
    } finally {
      if (accepts(ticket)) {
        membersLoading = false;
        changed();
      }
    }
  }

  MemberPresence memberPresence(GuildMember member) =>
      guildPresence.resolve(member.id, member.presence);
}
