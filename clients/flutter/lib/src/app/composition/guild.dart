import '../../features/guild/profile/controller.dart';
import 'owners.dart';

void configureGuild(AppOwners app) {
  app.guildProfile = GuildProfileController(app.api.guildProfile)
    ..addListener(app.notifyListeners);
}
