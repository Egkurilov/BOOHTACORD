enum ChannelKind { text, voice }

class SessionUser {
  const SessionUser({required this.accountId, required this.role});
  final String accountId;
  final String role;
  bool get isAdmin => role == 'ADMINISTRATOR';
  factory SessionUser.fromJson(Map<String, dynamic> json) => SessionUser(
    accountId: json['account_id'] as String,
    role: json['role'] as String,
  );
}

class GuildChannel {
  const GuildChannel({
    required this.id,
    required this.name,
    required this.kind,
    required this.admissionClosed,
  });
  final String id;
  final String name;
  final ChannelKind kind;
  final bool admissionClosed;
  factory GuildChannel.fromJson(Map<String, dynamic> json) => GuildChannel(
    id: json['id'] as String,
    name: json['name'] as String,
    kind: json['kind'] == 'VOICE' ? ChannelKind.voice : ChannelKind.text,
    admissionClosed: json['admission_closed'] as bool? ?? false,
  );
}

class ChannelCategory {
  const ChannelCategory({
    required this.id,
    required this.name,
    required this.channels,
  });
  final String id;
  final String name;
  final List<GuildChannel> channels;
  factory ChannelCategory.fromJson(Map<String, dynamic> json) =>
      ChannelCategory(
        id: json['id'] as String,
        name: json['name'] as String,
        channels: (json['channels'] as List<dynamic>)
            .map(
              (value) => GuildChannel.fromJson(value as Map<String, dynamic>),
            )
            .toList(growable: false),
      );
}

class ChannelTopology {
  const ChannelTopology({required this.revision, required this.categories});
  final int revision;
  final List<ChannelCategory> categories;
  factory ChannelTopology.fromJson(Map<String, dynamic> json) =>
      ChannelTopology(
        revision: json['revision'] as int,
        categories: (json['categories'] as List<dynamic>)
            .map(
              (value) =>
                  ChannelCategory.fromJson(value as Map<String, dynamic>),
            )
            .toList(growable: false),
      );
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.channelId,
    required this.authorId,
    required this.body,
    required this.createdAt,
    required this.deleted,
    required this.revision,
  });
  final String id;
  final String channelId;
  final String authorId;
  final String body;
  final DateTime createdAt;
  final bool deleted;
  final int revision;
  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id'] as String,
    channelId: json['channel_id'] as String,
    authorId: json['author_id'] as String,
    body: json['body'] as String? ?? '',
    createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    deleted: json['deleted'] as bool? ?? false,
    revision: json['revision'] as int,
  );
}

class VoiceCredential {
  const VoiceCredential({required this.url, required this.token});
  final String url;
  final String token;
}
