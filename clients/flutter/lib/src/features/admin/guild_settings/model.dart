import '../../guild/profile/model.dart';

class GuildSettings extends GuildProfile {
  const GuildSettings(super.name, super.revision, this.welcome);
  final String? welcome;
  factory GuildSettings.fromJson(Map<String, dynamic> json) {
    final profile = GuildProfile.fromJson(json),
        welcome = json['welcome_channel_id'];
    if (welcome != null &&
        (welcome is! String ||
            !RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(welcome))) {
      throw const FormatException('Некорректный welcome-канал.');
    }
    return GuildSettings(profile.name, profile.revision, welcome as String?);
  }
}
