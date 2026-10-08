import 'dart:convert';

import '../../../models.dart';
import '../../../core/http/transport.dart';
import 'candidate_page.dart';

class DirectConversationsApi {
  DirectConversationsApi(this.transport);
  final ApiTransport transport;

  Future<List<DirectConversation>> directMessages() async {
    final data = await transport.checked(
      await transport.client.get(
        transport.uri('/direct-messages'),
        headers: await transport.headers(),
      ),
    ) as Map<String, dynamic>;
    return (data['direct_messages'] as List<dynamic>)
        .map(
          (value) => DirectConversation.fromJson(value as Map<String, dynamic>),
        )
        .toList(growable: false);
  }

  Future<List<DirectCandidate>> directMessageCandidates() async {
    final result = <DirectCandidate>[];
    String? after;
    do {
      final page = await candidatePage(after: after);
      result.addAll(page.items);
      after = page.nextAfter;
    } while (after != null);
    return result;
  }

  Future<DirectCandidatePage> candidatePage({String? after}) async {
    final data = await transport.checked(
      await transport.client.get(
        transport.uri('/direct-message-candidates', {
          'limit': '100',
          'after': ?after,
        }),
        headers: await transport.headers(),
      ),
    ) as Map<String, dynamic>;
    return DirectCandidatePage(
      items: (data['candidates'] as List<dynamic>)
          .map((v) => DirectCandidate.fromJson(v as Map<String, dynamic>))
          .toList(growable: false),
      nextAfter: data['next_after'] as String?,
    );
  }

  Future<String> openDirectMessage(String participantId) async {
    final data = await transport.checked(
      await transport.client.post(
        transport.uri('/direct-messages'),
        headers: await transport.headers(jsonBody: true),
        body: jsonEncode({'participant_id': participantId}),
      ),
    ) as Map<String, dynamic>;
    return data['id'] as String;
  }
}
