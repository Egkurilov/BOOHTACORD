import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/core/session/scope.dart';
import 'package:boohtacord_desktop/src/features/profile/state/controller.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';

const own = OwnProfile(
  accountId: 'account',
  login: 'login',
  displayName: 'Name',
  role: 'MEMBER',
);

class DelayedProfileApi extends ApiClient {
  final response = Completer<OwnProfile>();
  final uploaded = Completer<void>();
  int reads = 0;
  @override
  Future<OwnProfile> ownProfile() {
    reads++;
    return response.future;
  }

  @override
  Future<void> uploadOwnAvatar(Uint8List bytes, String contentType) =>
      uploaded.future;
}

void main() {
  test('late profile cannot repopulate a closed account', () async {
    final api = DelayedProfileApi();
    final scope = SessionScope();
    final state = ProfileController(
      api,
      scope,
      error: (_) {},
      refreshMembers: () async {},
    );
    addTearDown(state.dispose);
    final request = state.refreshProfile();
    scope.close();
    state.clear();
    api.response.complete(own);
    await request;
    expect(state.profile, isNull);
    expect(state.profileLoading, isFalse);
  });

  test(
    'late avatar upload cannot fetch or update a replacement account',
    () async {
      final api = DelayedProfileApi();
      final scope = SessionScope();
      final state = ProfileController(
        api,
        scope,
        error: (_) {},
        refreshMembers: () async {},
      );
      addTearDown(state.dispose);
      final request = state.uploadAvatar(Uint8List.fromList([1]), 'image/png');
      scope.close();
      state.clear();
      scope.begin();
      api.uploaded.complete();
      expect(await request, isFalse);
      expect(api.reads, 0);
      expect(state.avatarRevision, 0);
    },
  );

  test(
    'disposed profile load does not notify or retain private data',
    () async {
      final api = DelayedProfileApi();
      final state = ProfileController(
        api,
        SessionScope(),
        error: (_) {},
        refreshMembers: () async {},
      );
      final request = state.refreshProfile();
      state.dispose();
      api.response.complete(own);
      await request;
      expect(state.profile, isNull);
    },
  );
}
