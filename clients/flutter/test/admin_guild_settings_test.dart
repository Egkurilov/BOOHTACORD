import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/features/admin/guild_settings/controller.dart';
import 'package:boohtacord_desktop/src/features/admin/guild_settings/model.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';

void main() {
  test(
    'conflict preserves drafts and reloads revision before explicit retry',
    () async {
      var reads = 0, writes = 0;
      final state = GuildSettingsController(
        () async => GuildSettings('Другой', ++reads, null),
        (name, channel, revision) async {
          writes++;
          if (writes == 1) throw ApiFailure('conflict', status: 409);
          expect(revision, 2);
          return GuildSettings(name, 3, channel);
        },
      );
      await state.load();
      state.name = 'Черновик';
      await state.save([]);
      expect(state.name, 'Черновик');
      expect(state.revision, 2);
      expect(writes, 1);
      await state.save([]);
      expect(state.saved, true);
      state.dispose();
    },
  );
  test('unavailable welcome channel rejects before mutation', () async {
    var writes = 0;
    final state = GuildSettingsController(
      () async => const GuildSettings('Имя', 1, null),
      (name, channel, revision) async {
        writes++;
        return GuildSettings(name, 2, channel);
      },
    );
    await state.load();
    state.welcome = 'archived';
    await state.save([]);
    expect(writes, 0);
    expect(state.error, contains('канал'));
    state.dispose();
  });
}
