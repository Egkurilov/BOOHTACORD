import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const textChannel = GuildChannel(
    id: 'channel-1',
    name: 'общий',
    kind: ChannelKind.text,
    admissionClosed: false,
  );
  const topology = ChannelTopology(
    revision: 1,
    categories: [
      ChannelCategory(
        id: 'category-1',
        name: 'Текстовые каналы',
        channels: [textChannel],
      ),
    ],
  );

  test('restores a session and selects the first text channel', () async {
    final api = _FakeApi(topology);
    final state = AppState(api);

    await state.initialize();

    expect(state.phase, AppPhase.ready);
    expect(state.user?.accountId, 'account-1');
    expect(state.selectedChannel?.id, textChannel.id);
    expect(state.messages, hasLength(1));
  });

  test('adds a server-confirmed message to the conversation', () async {
    final state = AppState(_FakeApi(topology));
    await state.initialize();

    final sent = await state.send('Новое сообщение');

    expect(sent, isTrue);
    expect(state.messages.last.body, 'Новое сообщение');
    expect(state.sending, isFalse);
  });

  test('offers an explicit transfer for an existing voice lease', () async {
    final api = _FakeApi(
      topology,
      voiceFailure: const ApiFailure(
        'Голос уже подключён в другом окне',
        status: 409,
        code: 'ACTIVE_VOICE_LEASE',
      ),
    );
    final state = AppState(api);
    const voiceChannel = GuildChannel(
      id: 'voice-1',
      name: 'Лобби',
      kind: ChannelKind.voice,
      admissionClosed: false,
    );

    await state.joinVoice(voiceChannel);

    expect(state.voicePhase, VoicePhase.error);
    expect(state.transferRequired, isTrue);
    expect(state.error, contains('Перенесите подключение'));
  });
}

class _FakeApi extends ApiClient {
  _FakeApi(this.value, {this.voiceFailure});
  final ChannelTopology value;
  final ApiFailure? voiceFailure;

  @override
  Future<void> initialize() async {}

  @override
  Future<SessionUser?> currentSession() async =>
      const SessionUser(accountId: 'account-1', role: 'MEMBER');

  @override
  Future<ChannelTopology> topology() async => value;

  @override
  Future<List<ChatMessage>> messages(String channelId) async => [
    ChatMessage(
      id: 'message-1',
      channelId: channelId,
      authorId: 'account-1',
      body: 'Первое сообщение',
      createdAt: DateTime.utc(2026, 9, 20),
      deleted: false,
      revision: 1,
    ),
  ];

  @override
  Future<ChatMessage> sendMessage(
    String channelId,
    String clientMessageId,
    String body,
  ) async => ChatMessage(
    id: 'message-2',
    channelId: channelId,
    authorId: 'account-1',
    body: body,
    createdAt: DateTime.utc(2026, 9, 20, 1),
    deleted: false,
    revision: 1,
  );

  @override
  Future<(String, VoiceCredential)> voiceCredential(
    String channelId, {
    bool transfer = false,
  }) async {
    if (voiceFailure case final failure?) throw failure;
    return (
      'lease-1',
      const VoiceCredential(url: 'wss://voice.example.test', token: 'token'),
    );
  }
}
