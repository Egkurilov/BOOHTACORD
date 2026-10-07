import 'package:boohtacord_desktop/src/core/http/api_failure.dart';
import 'package:boohtacord_desktop/src/features/admin/members/controller.dart';
import 'package:boohtacord_desktop/src/features/admin/members/models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_api.dart';

void main() {
  test('409 keeps baseline and both admin drafts until explicit review', () async {
    final api = MembersApiFake();
    api.pages[null] = AdminAccountPage(accounts: [member('a'), member('b')]);
    final directory = AdminMembersController(api);
    addTearDown(directory.dispose);
    await directory.load();
    directory.updateDraftRole('a', 'ADMINISTRATOR');
    directory.updateDraftBlocked('a', true);
    directory.updateDraftBlocked('b', true);
    api.pages[null] = AdminAccountPage(accounts: [
      member('a', blocked: true, version: 2),
      member('b', role: 'ADMINISTRATOR', version: 2),
    ]);
    api.onSave = (_, __, ___, ____) => throw const ApiFailure('Conflict', status: 409);

    await directory.saveAccount('a');

    expect(api.expectedTimestamps.single, DateTime.utc(2026, 1, 1, 0, 1));
    expect(directory.conflicts['a']?.before.role, 'MEMBER');
    expect(directory.conflicts['a']?.before.blocked, isFalse);
    expect(directory.conflicts['a']?.current?.updatedAt, member('a', blocked: true, version: 2).updatedAt);
    expect(directory.drafts['a'], const AdminMemberDraft(role: 'ADMINISTRATOR', blocked: true));
    expect(directory.drafts['b'], const AdminMemberDraft(role: 'MEMBER', blocked: true));
    expect(directory.conflicts['b']?.before.role, 'MEMBER');
    expect(directory.conflicts['b']?.before.blocked, isFalse);

    await directory.saveAccount('a');
    expect(api.expectedTimestamps, [DateTime.utc(2026, 1, 1, 0, 1)]);

    directory.resolveConflict('a', discard: false);
    api.onSave = (id, role, blocked, _) async {
      final current = api.pages[null]!.accounts.firstWhere((item) => item.accountId == id);
      api.pages[null] = AdminAccountPage(accounts: [
        member(id, role: role, blocked: blocked, version: 3),
        ...api.pages[null]!.accounts.where((item) => item.accountId != id),
      ]);
      expect(current.accountId, id);
    };
    await directory.saveAccount('a');

    expect(api.expectedTimestamps.last, DateTime.utc(2026, 1, 1, 0, 2));
    expect(directory.baseline['a']?.updatedAt, DateTime.utc(2026, 1, 1, 0, 3));
    expect(directory.drafts['a'], const AdminMemberDraft(role: 'ADMINISTRATOR', blocked: true));
  });
}
