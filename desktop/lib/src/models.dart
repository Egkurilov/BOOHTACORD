enum ChannelKind { text, voice }

enum SearchMessageKind { channel, directMessage }

class VoiceRosterMember {
  const VoiceRosterMember({
    required this.accountId,
    required this.displayName,
    required this.screenSharing,
    this.microphoneMuted = true,
  });

  final String accountId;
  final String displayName;
  final bool screenSharing;
  final bool microphoneMuted;

  factory VoiceRosterMember.fromJson(Map<String, dynamic> json) {
    final accountId = json['account_id'];
    final displayName = json['display_name'];
    final screenSharing = json['screen_sharing'];
    final microphoneMuted = json['microphone_muted'];
    if (accountId is! String ||
        accountId.trim().isEmpty ||
        displayName is! String ||
        displayName.trim().isEmpty ||
        screenSharing is! bool ||
        (microphoneMuted != null && microphoneMuted is! bool)) {
      throw const FormatException('Invalid voice roster member.');
    }
    return VoiceRosterMember(
      accountId: accountId,
      displayName: displayName,
      screenSharing: screenSharing,
      microphoneMuted: microphoneMuted is bool ? microphoneMuted : true,
    );
  }
}

class VoiceRoomRoster {
  const VoiceRoomRoster({required this.channelId, required this.participants});

  final String channelId;
  final List<VoiceRosterMember> participants;

  factory VoiceRoomRoster.fromJson(Map<String, dynamic> json) {
    final channelId = json['channel_id'];
    final members = json['participants'];
    if (channelId is! String || channelId.trim().isEmpty || members is! List) {
      throw const FormatException('Invalid voice room roster.');
    }
    final participants = members
        .map(
          (value) => VoiceRosterMember.fromJson(value as Map<String, dynamic>),
        )
        .toList(growable: false);
    if (participants.map((item) => item.accountId).toSet().length !=
        participants.length) {
      throw const FormatException('Duplicate voice roster member.');
    }
    return VoiceRoomRoster(channelId: channelId, participants: participants);
  }
}

bool _isUuid(Object? value) =>
    value is String &&
    RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      caseSensitive: false,
    ).hasMatch(value);

class SearchMessage {
  const SearchMessage({
    required this.id,
    required this.kind,
    required this.conversationId,
    required this.authorId,
    required this.body,
    required this.createdAt,
    required this.revision,
    this.editedAt,
  });
  final String id;
  final SearchMessageKind kind;
  final String conversationId;
  final String authorId;
  final String body;
  final DateTime createdAt;
  final DateTime? editedAt;
  final int revision;

  factory SearchMessage.fromJson(Map<String, dynamic> json) {
    final kind = switch (json['kind']) {
      'CHANNEL' => SearchMessageKind.channel,
      'DIRECT_MESSAGE' => SearchMessageKind.directMessage,
      _ => throw const FormatException('Invalid search result kind.'),
    };
    final id = json['id'];
    final authorId = json['author_id'];
    final conversationId = kind == SearchMessageKind.channel
        ? json['channel_id']
        : json['direct_message_id'];
    final body = json['body'] as String;
    final revision = json['revision'] as int;
    final createdAt = DateTime.parse(json['created_at'] as String).toLocal();
    final editedAt = json['edited_at'] == null
        ? null
        : DateTime.parse(json['edited_at'] as String).toLocal();
    if (!_isUuid(id) ||
        !_isUuid(authorId) ||
        !_isUuid(conversationId) ||
        body.isEmpty ||
        revision < 1 ||
        (kind == SearchMessageKind.channel &&
            json.containsKey('direct_message_id')) ||
        (kind == SearchMessageKind.directMessage &&
            json.containsKey('channel_id'))) {
      throw const FormatException('Invalid search result.');
    }
    return SearchMessage(
      id: id as String,
      kind: kind,
      conversationId: conversationId as String,
      authorId: authorId as String,
      body: body,
      createdAt: createdAt,
      editedAt: editedAt,
      revision: revision,
    );
  }
}

class SearchMessagePage {
  const SearchMessagePage({required this.messages, this.nextCursor});
  final List<SearchMessage> messages;
  final String? nextCursor;
}

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

class AdminAuditEvent {
  const AdminAuditEvent({
    required this.id,
    required this.eventType,
    required this.createdAt,
    this.actorUserId,
    this.actorDisplayName,
    this.actorLogin,
    this.targetUserId,
    this.targetDisplayName,
    this.targetLogin,
  });

  final String id;
  final String eventType;
  final DateTime createdAt;
  final String? actorUserId;
  final String? actorDisplayName;
  final String? actorLogin;
  final String? targetUserId;
  final String? targetDisplayName;
  final String? targetLogin;

  factory AdminAuditEvent.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final eventType = json['event_type'];
    final createdAt = json['created_at'];
    if (id is! String ||
        id.isEmpty ||
        eventType is! String ||
        eventType.isEmpty ||
        createdAt is! String) {
      throw const FormatException('Invalid admin audit event.');
    }
    String? optionalText(String key) {
      final value = json[key];
      if (value == null) return null;
      if (value is! String) {
        throw const FormatException('Invalid admin audit event.');
      }
      return value;
    }

    return AdminAuditEvent(
      id: id,
      eventType: eventType,
      createdAt: DateTime.parse(createdAt).toLocal(),
      actorUserId: optionalText('actor_user_id'),
      actorDisplayName: optionalText('actor_display_name'),
      actorLogin: optionalText('actor_login'),
      targetUserId: optionalText('target_user_id'),
      targetDisplayName: optionalText('target_display_name'),
      targetLogin: optionalText('target_login'),
    );
  }
}

class AdminAuditPage {
  const AdminAuditPage({required this.events, this.nextCursor});

  final List<AdminAuditEvent> events;
  final String? nextCursor;
}

class AdminScreenSample {
  const AdminScreenSample({
    required this.platform,
    required this.direction,
    required this.state,
    required this.sampledAtUtc,
    this.frameWidth,
    this.frameHeight,
    this.encodedFps,
    this.decodedFps,
    this.presentedFps,
    this.bitrateKbps,
    this.jitterMs,
    this.packetsLost,
    this.droppedFrames,
    this.rttMs,
  });

  static const platforms = {
    'ios_web',
    'android_web',
    'desktop_web',
    'android_native',
    'desktop_native',
  };
  static const directions = {'sender', 'receiver'};
  static const states = {
    'waiting_subscription',
    'waiting_first_frame',
    'playing',
    'stalled',
  };

  final String platform;
  final String direction;
  final String state;
  final DateTime sampledAtUtc;
  final int? frameWidth;
  final int? frameHeight;
  final double? encodedFps;
  final double? decodedFps;
  final double? presentedFps;
  final double? bitrateKbps;
  final double? jitterMs;
  final int? packetsLost;
  final int? droppedFrames;
  final double? rttMs;

  factory AdminScreenSample.fromJson(Map<String, dynamic> json) {
    final report = json['report'];
    final sampledAt = json['sampled_at_utc'];
    if (report is! Map<String, dynamic> || sampledAt is! String) {
      throw const FormatException('Invalid admin screen sample.');
    }
    final platform = report['platform'];
    final direction = report['direction'];
    final state = report['state'];
    DateTime parsedSampledAt;
    try {
      parsedSampledAt = DateTime.parse(sampledAt).toUtc();
    } on FormatException {
      throw const FormatException('Invalid admin screen sample.');
    }
    if (!parsedSampledAt.isUtc ||
        platform is! String ||
        !platforms.contains(platform) ||
        direction is! String ||
        !directions.contains(direction) ||
        state is! String ||
        !states.contains(state)) {
      throw const FormatException('Invalid admin screen sample.');
    }

    double? optionalNumber(String key, double maximum) {
      final value = report[key];
      if (value == null) return null;
      if (value is! num || !value.isFinite || value < 0 || value > maximum) {
        throw const FormatException('Invalid admin screen sample.');
      }
      return value.toDouble();
    }

    int? optionalInteger(String key, int maximum) {
      final value = report[key];
      if (value == null) return null;
      if (value is! int || value < 0 || value > maximum) {
        throw const FormatException('Invalid admin screen sample.');
      }
      return value;
    }

    int? optionalDimension(String key) {
      final value = report[key];
      if (value == null) return null;
      if (value is! int || value < 1 || value > 8192) {
        throw const FormatException('Invalid admin screen sample.');
      }
      return value;
    }

    final frameWidth = optionalDimension('frame_width');
    final frameHeight = optionalDimension('frame_height');
    final encodedFps = optionalNumber('encoded_fps', 240);
    final decodedFps = optionalNumber('decoded_fps', 240);
    if ((frameWidth == null) != (frameHeight == null) ||
        (direction == 'sender' && decodedFps != null) ||
        (direction == 'receiver' && encodedFps != null)) {
      throw const FormatException('Invalid admin screen sample.');
    }
    return AdminScreenSample(
      platform: platform,
      direction: direction,
      state: state,
      sampledAtUtc: parsedSampledAt,
      frameWidth: frameWidth,
      frameHeight: frameHeight,
      encodedFps: encodedFps,
      decodedFps: decodedFps,
      presentedFps: optionalNumber('presented_fps', 240),
      bitrateKbps: optionalNumber('bitrate_kbps', 100000),
      jitterMs: optionalNumber('jitter_ms', 60000),
      packetsLost: optionalInteger('packets_lost', 1000000000),
      droppedFrames: optionalInteger('dropped_frames', 1000000000),
      rttMs: optionalNumber('rtt_ms', 60000),
    );
  }
}

class AdminAccount {
  const AdminAccount({
    required this.accountId,
    required this.login,
    required this.displayName,
    required this.role,
    required this.blocked,
    required this.createdAt,
  });

  final String accountId;
  final String login;
  final String displayName;
  final String role;
  final bool blocked;
  final DateTime createdAt;

  factory AdminAccount.fromJson(Map<String, dynamic> json) {
    final accountId = json['account_id'];
    final login = json['login'];
    final displayName = json['display_name'];
    final role = json['role'];
    final blocked = json['blocked'];
    final createdAt = json['created_at'];
    if (accountId is! String ||
        accountId.isEmpty ||
        login is! String ||
        displayName is! String ||
        (role != 'MEMBER' && role != 'ADMINISTRATOR') ||
        blocked is! bool ||
        createdAt is! String) {
      throw const FormatException('Invalid admin account.');
    }
    return AdminAccount(
      accountId: accountId,
      login: login,
      displayName: displayName,
      role: role as String,
      blocked: blocked,
      createdAt: DateTime.parse(createdAt).toLocal(),
    );
  }
}

class AdminAccountPage {
  const AdminAccountPage({required this.accounts, this.nextCursor});

  final List<AdminAccount> accounts;
  final String? nextCursor;
}

class AdminPasswordResetLink {
  const AdminPasswordResetLink({required this.url, required this.expiresAt});

  final String url;
  final DateTime expiresAt;
}

class OwnProfile {
  const OwnProfile({
    required this.accountId,
    required this.login,
    required this.displayName,
    required this.role,
    this.avatarUrl,
  });
  final String accountId;
  final String login;
  final String displayName;
  final String role;
  final String? avatarUrl;

  factory OwnProfile.fromJson(Map<String, dynamic> json) => OwnProfile(
    accountId: json['account_id'] as String,
    login: json['login'] as String,
    displayName: json['display_name'] as String,
    role: json['role'] as String,
    avatarUrl: json['avatar_url'] as String?,
  );
}

class GuildChannel {
  const GuildChannel({
    required this.id,
    required this.name,
    required this.kind,
    required this.admissionClosed,
    this.unreadCount = 0,
    this.mentionCount = 0,
  });
  final String id;
  final String name;
  final ChannelKind kind;
  final bool admissionClosed;
  final int unreadCount;
  final int mentionCount;

  GuildChannel withUnreadCounts({required int unread, required int mentions}) =>
      GuildChannel(
        id: id,
        name: name,
        kind: kind,
        admissionClosed: admissionClosed,
        unreadCount: unread,
        mentionCount: mentions,
      );

  factory GuildChannel.fromJson(Map<String, dynamic> json) {
    final kind = json['kind'] == 'VOICE' ? ChannelKind.voice : ChannelKind.text;
    return GuildChannel(
      id: json['id'] as String,
      name: json['name'] as String,
      kind: kind,
      admissionClosed: json['admission_closed'] as bool? ?? false,
      unreadCount: kind == ChannelKind.text
          ? _nonNegativeCount(json['unread_count'])
          : 0,
      mentionCount: kind == ChannelKind.text
          ? _nonNegativeCount(json['mention_count'])
          : 0,
    );
  }
}

int _nonNegativeCount(Object? value) {
  if (value == null) return 0;
  if (value is int && value >= 0) return value;
  throw const FormatException('Invalid channel message count.');
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

class MessageAttachment {
  const MessageAttachment({
    required this.id,
    required this.originalName,
    required this.sizeBytes,
  });
  final String id;
  final String originalName;
  final int sizeBytes;

  factory MessageAttachment.fromJson(Map<String, dynamic> json) {
    final size = json['byte_size'];
    final id = json['id'];
    final originalName = json['original_name'];
    if (id is! String ||
        id.isEmpty ||
        originalName is! String ||
        originalName.isEmpty ||
        size is! int ||
        size < 0 ||
        size > 25000000) {
      throw const FormatException('Invalid message attachment size.');
    }
    return MessageAttachment(
      id: id,
      originalName: originalName,
      sizeBytes: size,
    );
  }
}

enum MessageSendStatus { sending, failed }

List<MessageAttachment> _messageAttachments(Object? value) {
  if (value == null) return const [];
  if (value is! List) {
    throw const FormatException('Invalid message attachments.');
  }
  if (value.length > 10) {
    throw const FormatException('Too many message attachments.');
  }
  return value
      .map((item) => MessageAttachment.fromJson(item as Map<String, dynamic>))
      .toList(growable: false);
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
    this.clientMessageId,
    this.sendStatus,
    this.replyToId,
    this.mentionUserIds = const [],
    this.attachments = const [],
    this.editedAt,
  });
  final String id;
  final String channelId;
  final String authorId;
  final String body;
  final DateTime createdAt;
  final bool deleted;
  final int revision;
  final String? clientMessageId;
  final MessageSendStatus? sendStatus;
  final String? replyToId;
  final List<String> mentionUserIds;
  final List<MessageAttachment> attachments;
  final DateTime? editedAt;
  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id'] as String,
    channelId: json['channel_id'] as String,
    authorId: json['author_id'] as String,
    body: json['body'] as String? ?? '',
    createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    deleted: json['deleted'] as bool? ?? false,
    revision: json['revision'] as int,
    clientMessageId: json['client_message_id'] as String?,
    replyToId: json['reply_to_id'] as String?,
    mentionUserIds: (json['mention_user_ids'] as List<dynamic>? ?? const [])
        .whereType<String>()
        .toList(growable: false),
    attachments: _messageAttachments(json['attachments']),
    editedAt: json['edited_at'] == null
        ? null
        : DateTime.parse(json['edited_at'] as String).toLocal(),
  );

  ChatMessage withSendStatus(MessageSendStatus status) => ChatMessage(
    id: id,
    channelId: channelId,
    authorId: authorId,
    body: body,
    createdAt: createdAt,
    deleted: deleted,
    revision: revision,
    clientMessageId: clientMessageId,
    sendStatus: status,
    replyToId: replyToId,
    mentionUserIds: mentionUserIds,
    attachments: attachments,
    editedAt: editedAt,
  );

  ChatMessage asDeleted() => ChatMessage(
    id: id,
    channelId: channelId,
    authorId: authorId,
    body: '',
    createdAt: createdAt,
    deleted: true,
    revision: revision + 1,
    clientMessageId: clientMessageId,
    replyToId: replyToId,
  );
}

class ChatMessagePage {
  const ChatMessagePage({required this.messages, this.nextCursor});
  final List<ChatMessage> messages;
  final String? nextCursor;
}

class VoiceCredential {
  const VoiceCredential({required this.url, required this.token});
  final String url;
  final String token;
}

enum MemberPresence { online, offline, unknown }

class GuildMember {
  const GuildMember({
    required this.id,
    required this.login,
    required this.displayName,
    required this.role,
    required this.presence,
    this.avatarUrl,
  });
  final String id;
  final String login;
  final String displayName;
  final String role;
  final MemberPresence presence;
  final String? avatarUrl;

  GuildMember withPresence(MemberPresence value) => GuildMember(
    id: id,
    login: login,
    displayName: displayName,
    role: role,
    presence: value,
    avatarUrl: avatarUrl,
  );

  factory GuildMember.fromJson(Map<String, dynamic> json) => GuildMember(
    id: json['user_id'] as String,
    login: json['login'] as String,
    displayName: json['display_name'] as String,
    role: json['role'] as String,
    presence: switch (json['presence']) {
      'online' => MemberPresence.online,
      'offline' => MemberPresence.offline,
      _ => MemberPresence.unknown,
    },
    avatarUrl: json['avatar_url'] as String?,
  );
}

class DirectConversation {
  const DirectConversation({
    required this.id,
    required this.participantId,
    required this.displayName,
    required this.unreadCount,
  });
  final String id;
  final String participantId;
  final String displayName;
  final int unreadCount;

  DirectConversation withUnreadCount(int value) => DirectConversation(
    id: id,
    participantId: participantId,
    displayName: displayName,
    unreadCount: value,
  );

  factory DirectConversation.fromJson(Map<String, dynamic> json) =>
      DirectConversation(
        id: json['id'] as String,
        participantId: json['other_participant_id'] as String,
        displayName: json['other_participant_display_name'] as String,
        unreadCount: json['unread_count'] as int,
      );
}

class DirectCandidate {
  const DirectCandidate({required this.id, required this.displayName});
  final String id;
  final String displayName;
  factory DirectCandidate.fromJson(Map<String, dynamic> json) =>
      DirectCandidate(
        id: json['id'] as String,
        displayName: json['display_name'] as String,
      );
}

class DirectMessageReplyPreview {
  const DirectMessageReplyPreview({
    required this.id,
    required this.authorId,
    required this.body,
    required this.deleted,
  });

  final String id;
  final String authorId;
  final String body;
  final bool deleted;

  factory DirectMessageReplyPreview.fromJson(Map<String, dynamic> json) =>
      DirectMessageReplyPreview(
        id: json['id'] as String,
        authorId: json['author_id'] as String,
        body: json['body'] as String? ?? '',
        deleted: json['deleted'] as bool? ?? false,
      );
}

class DirectChatMessage {
  const DirectChatMessage({
    required this.id,
    required this.directMessageId,
    required this.authorId,
    required this.body,
    required this.createdAt,
    required this.deleted,
    required this.revision,
    this.clientMessageId,
    this.sendStatus,
    this.mentionUserIds = const [],
    this.replyToId,
    this.replyPreview,
    this.attachments = const [],
    this.editedAt,
  });
  final String id;
  final String directMessageId;
  final String authorId;
  final String body;
  final DateTime createdAt;
  final bool deleted;
  final int revision;
  final String? clientMessageId;
  final MessageSendStatus? sendStatus;
  final List<String> mentionUserIds;
  final String? replyToId;
  final DirectMessageReplyPreview? replyPreview;
  final List<MessageAttachment> attachments;
  final DateTime? editedAt;

  factory DirectChatMessage.fromJson(Map<String, dynamic> json) =>
      DirectChatMessage(
        id: json['id'] as String,
        directMessageId: json['direct_message_id'] as String,
        authorId: json['author_id'] as String,
        body: json['body'] as String? ?? '',
        createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
        deleted: json['deleted'] as bool? ?? false,
        revision: json['revision'] as int,
        clientMessageId: json['client_message_id'] as String?,
        mentionUserIds: (json['mention_user_ids'] as List<dynamic>? ?? const [])
            .whereType<String>()
            .toList(growable: false),
        replyToId: json['reply_to_id'] as String?,
        replyPreview: json['reply_preview'] is Map<String, dynamic>
            ? DirectMessageReplyPreview.fromJson(
                json['reply_preview'] as Map<String, dynamic>,
              )
            : null,
        attachments: _messageAttachments(json['attachments']),
        editedAt: json['edited_at'] == null
            ? null
            : DateTime.parse(json['edited_at'] as String).toLocal(),
      );

  DirectChatMessage withSendStatus(MessageSendStatus status) =>
      DirectChatMessage(
        id: id,
        directMessageId: directMessageId,
        authorId: authorId,
        body: body,
        createdAt: createdAt,
        deleted: deleted,
        revision: revision,
        clientMessageId: clientMessageId,
        sendStatus: status,
        mentionUserIds: mentionUserIds,
        replyToId: replyToId,
        replyPreview: replyPreview,
        attachments: attachments,
        editedAt: editedAt,
      );

  DirectChatMessage asDeleted() => DirectChatMessage(
    id: id,
    directMessageId: directMessageId,
    authorId: authorId,
    body: '',
    createdAt: createdAt,
    deleted: true,
    revision: revision + 1,
    clientMessageId: clientMessageId,
    replyToId: replyToId,
    replyPreview: replyPreview,
  );
}

class DirectChatMessagePage {
  const DirectChatMessagePage({required this.messages, this.nextCursor});
  final List<DirectChatMessage> messages;
  final String? nextCursor;
}
