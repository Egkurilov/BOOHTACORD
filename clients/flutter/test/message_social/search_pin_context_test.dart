import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:boohtacord_desktop/src/screens/workspace_ui/workspace_search_panel/component.dart';

const channel = '11111111-1111-4111-8111-111111111111',
    message = '22222222-2222-4222-8222-222222222222',
    author = '33333333-3333-4333-8333-333333333333';
void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  testWidgets(
    'actual search pin opens original message through protected context API',
    (tester) async {
      final requests = <http.Request>[];
      final api = ApiClient(
        client: MockClient((request) async {
          requests.add(request);
          final data = request.url.path.endsWith('/pins')
              ? {
                  'can_manage': false,
                  'pins': [
                    {
                      'message_id': message,
                      'author_id': author,
                      'preview': 'Pinned preview',
                      'pinned_at': '2026-10-09T12:01:00Z',
                      'message_created_at': '2026-10-09T12:00:00Z',
                    },
                  ],
                }
              : {
                  'messages': [
                    {
                      'id': message,
                      'channel_id': channel,
                      'author_id': author,
                      'body': 'Full original',
                      'created_at': '2026-10-09T12:00:00Z',
                      'deleted': false,
                      'revision': 3,
                      'attachments': [],
                      'mention_user_ids': [],
                    },
                  ],
                };
          return http.Response(
            jsonEncode(data),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      final state = AppState(api);
      addTearDown(state.dispose);
      state.phase = AppPhase.ready;
      state.user = const SessionUser(accountId: author, role: 'MEMBER');
      const text = GuildChannel(
        id: channel,
        name: 'Text',
        kind: ChannelKind.text,
        admissionClosed: false,
      );
      state.workspace.topology = const ChannelTopology(
        revision: 1,
        categories: [
          ChannelCategory(id: author, name: 'Category', channels: [text]),
        ],
      );
      state.selectedChannel = text;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: WorkspaceWorkspaceSearchPanel(state: state)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Закреплённые'));
      await tester.pumpAndSettle();
      expect(find.text('Pinned preview'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('text-pin:$message')));
      await tester.pumpAndSettle();
      expect(state.searchContextMessage?.id, message);
      expect(state.searchContextMessage?.conversationId, channel);
      expect(state.searchContextTextMessages.single.body, 'Full original');
      expect(state.searchContextTextMessages.single.revision, 3);
      expect(requests.last.url.path, '/api/v1/channels/$channel/messages');
      expect(requests.last.url.queryParameters['at'], message);
    },
  );
}
