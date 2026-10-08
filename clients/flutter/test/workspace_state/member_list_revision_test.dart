import 'package:boohtacord_desktop/src/features/profile/revision/cache.dart';
import 'package:boohtacord_desktop/src/features/workspace/load_members/controller.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'member_profile_fakes.dart';

void main() {
  test('member list refresh preserves newer profile metadata and fresh presence', () async {
    final current = revisionMember(
      'Current name',
      9,
      presence: MemberPresence.online,
    );
    memberProfileRevisions.recordMember(current, 9);
    final stale = revisionMember(
      'Old name',
      8,
      presence: MemberPresence.offline,
    );
    memberProfileRevisions.recordMember(stale, 8);
    final workspace = workspaceFor(StaleMembersApi([stale]));
    addTearDown(workspace.dispose);
    workspace.members = [current];

    await workspace.refreshMembers();

    expect(workspace.members.single.displayName, 'Current name');
    expect(workspace.members.single.presence, MemberPresence.offline);
    expect(memberProfileRevisions.memberRevision(workspace.members.single), 9);
  });
}
