import 'dart:typed_data';

import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_api.dart';

void main() {
  test('A to B to A history selection ignores the first A response', () async {
    final api = ConversationFakeApi();
    final state = AppState(api)..phase = AppPhase.ready;
    addTearDown(state.dispose);
    final old = state.openDirectConversation(conversationA);
    await state.openDirectConversation(conversationB);
    await state.openDirectConversation(conversationA);
    api.firstPage.complete(DirectChatMessagePage(messages: [message('old')]));
    await old;
    expect(state.directMessageHistory.map((m) => m.id), ['new']);
  });

  test('late upload is rejected after logout', () async {
    final api = ConversationFakeApi();
    final state = AppState(api)..phase = AppPhase.ready;
    addTearDown(state.dispose);
    final upload = state.uploadAttachment(
      'name.txt',
      Uint8List.fromList([1]),
      channelId: 'channel',
    );
    final rejected = expectLater(upload, throwsA(isA<ApiFailure>()));
    await state.logout();
    api.uploaded.complete(
      const MessageAttachment(
        id: 'old',
        originalName: 'name.txt',
        sizeBytes: 1,
      ),
    );
    await rejected;
  });
}
