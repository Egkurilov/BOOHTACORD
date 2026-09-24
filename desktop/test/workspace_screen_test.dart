import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:boohtacord_desktop/src/screens/workspace_screen.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('portrait layout opens a channel at full width and returns', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    final state = AppState(_PortraitApi());
    await state.initialize();
    await tester.pumpWidget(MaterialApp(home: WorkspaceScreen(state: state)));

    expect(find.text('Моя гильдия'), findsOneWidget);
    expect(find.byTooltip('К списку каналов'), findsNothing);

    await tester.tap(find.text('общий'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('К списку каналов'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('К списку каналов'));
    await tester.pumpAndSettle();

    expect(find.text('Моя гильдия'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _PortraitApi extends ApiClient {
  static const channel = GuildChannel(
    id: 'channel-1',
    name: 'общий',
    kind: ChannelKind.text,
    admissionClosed: false,
  );

  @override
  bool get realtimeEnabled => false;

  @override
  Future<void> initialize() async {}

  @override
  Future<SessionUser?> currentSession() async =>
      const SessionUser(accountId: 'account-1', role: 'MEMBER');

  @override
  Future<OwnProfile> ownProfile() async => const OwnProfile(
    accountId: 'account-1',
    login: 'member',
    displayName: 'Участник',
    role: 'MEMBER',
  );

  @override
  Future<ChannelTopology> topology() async => const ChannelTopology(
    revision: 1,
    categories: [
      ChannelCategory(
        id: 'category-1',
        name: 'Текстовые каналы',
        channels: [channel],
      ),
    ],
  );

  @override
  Future<List<GuildMember>> members() async => const [];

  @override
  Future<List<DirectConversation>> directMessages() async => const [];

  @override
  Future<List<ChatMessage>> messages(String channelId) async => const [];
}
