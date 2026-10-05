bool validGuildName(String name) =>
    name.trim() == name &&
    name.runes.isNotEmpty &&
    name.runes.length <= 80 &&
    !name.runes.any(
      (point) =>
          point < 32 ||
          point >= 127 && point <= 159 ||
          point == 0x2028 ||
          point == 0x2029,
    );

class GuildProfile {
  const GuildProfile(this.name, this.revision);
  final String name;
  final int revision;
  factory GuildProfile.fromJson(Map<String, dynamic> json) {
    final name = json['name'], revision = json['revision'];
    if (name is! String ||
        !validGuildName(name) ||
        revision is! int ||
        revision < 1) {
      throw const FormatException('Некорректный профиль гильдии.');
    }
    return GuildProfile(name, revision);
  }
}
