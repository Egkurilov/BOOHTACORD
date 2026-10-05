import '../../../core/http/facade_base.dart';
import 'api.dart';
import 'model.dart';

mixin GuildProfileFacade on ApiFacadeBase {
  late final _guildProfile = GuildProfileApi(transport);
  Future<GuildProfile> guildProfile() =>
      transport.run(_guildProfile.read, allowClosed: true);
}
