import 'package:boohtacord_desktop/src/features/admin/members/controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_api.dart';

void main() {
  test('refresh after a conflict preserves loaded pages and unrelated draft', () async {
    final api = MembersApiFake()
      ..pages[null] = AdminAccountPage(accounts: [member('a')], nextCursor: 'next')
      ..pages['next'] = AdminAccountPage(accounts: [member('b')]);
    final directory = AdminMembersController(api);
    addTearDown(directory.dispose);
    await directory.load();
    await directory.loadNextPage();
    directory.updateDraftBlocked('b', true);
    api.pages[null] = AdminAccountPage(accounts: [member('a', version: 2)], nextCursor: 'next-v2');
    api.pages['next-v2'] = AdminAccountPage(accounts: [member('b', role: 'ADMINISTRATOR', version: 2)]);

    await directory.refresh();

    expect(directory.accounts.map((value) => value.accountId), ['a', 'b']);
    expect(directory.drafts['b']?.blocked, isTrue);
    expect(directory.conflicts['b']?.current?.role, 'ADMINISTRATOR');
    expect(api.cursors, [null, 'next', null, 'next-v2']);
  });
}
