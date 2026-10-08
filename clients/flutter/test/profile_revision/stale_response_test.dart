import 'dart:async';

import 'package:boohtacord_desktop/src/core/session/scope.dart';
import 'package:boohtacord_desktop/src/features/profile/revision/cache.dart';
import 'package:boohtacord_desktop/src/features/profile/state/controller.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:flutter_test/flutter_test.dart';

class StaleOwnProfileApi extends ApiClient {
  final reads = <Completer<OwnProfile>>[];

  @override
  Future<OwnProfile> ownProfile() {
    final result = Completer<OwnProfile>();
    reads.add(result);
    return result.future;
  }
}

void main() {
  test('older own-profile response cannot replace a newer revision', () async {
    final api = StaleOwnProfileApi();
    final state = ProfileController(
      api,
      SessionScope(),
      error: (_) {},
      refreshMembers: () async {},
    );
    addTearDown(state.dispose);

    final older = state.refreshProfile();
    final newer = state.refreshProfile();
    api.reads[1].complete(_profile('New', 8));
    await newer;
    api.reads[0].complete(_profile('Old', 7));
    await older;

    expect(state.profile?.displayName, 'New');
    expect(state.profileRevision, 8);
  });
}

OwnProfile _profile(String name, int revision) {
  final profile = OwnProfile(
    accountId: 'u1',
    login: 'login',
    displayName: name,
    role: 'MEMBER',
  );
  memberProfileRevisions.recordOwn(profile, revision);
  return profile;
}
