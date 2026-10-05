import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:boohtacord_desktop/src/features/guild/profile/model.dart';
import 'package:boohtacord_desktop/src/features/guild/profile/controller.dart';

void main() {
  test('public profile drops private settings and sends no cookie', () async {
    final api = ApiClient(
      client: MockClient((request) async {
        expect(request.headers.containsKey('cookie'), false);
        return http.Response(
          jsonEncode({
            'name': 'Имя 🙂',
            'revision': 2,
            'welcome_channel_id': 'private',
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    final profile = await api.guildProfile();
    expect(profile.name, 'Имя 🙂');
    expect(profile.revision, 2);
  });
  test('profile rejects controls and eighty-one code points', () {
    for (final name in ['', 'X\nY', List.filled(81, '🙂').join()]) {
      expect(
        () => GuildProfile.fromJson({'name': name, 'revision': 1}),
        throwsFormatException,
      );
    }
  });
  test(
    'revision monotonic and responses after server reset discarded',
    () async {
      var revision = 3;
      final controller = GuildProfileController(
        () => Future.value(GuildProfile('Имя', revision)),
      );
      await controller.refresh();
      revision = 2;
      await controller.refresh();
      expect(controller.revision, 3);
      controller.reset();
      expect(controller.name, 'BOOHTACORD');
      controller.dispose();
    },
  );
}
