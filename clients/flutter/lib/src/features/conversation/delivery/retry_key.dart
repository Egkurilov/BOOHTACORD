import 'dart:convert';

import '../../conversation/lifecycle/controller.dart';

extension ConversationSendRetryKey on ConversationController {
  String sendRetryKey(
    String kind,
    String conversationId,
    String body,
    String? replyToId,
    List<String> mentions,
    List<String> attachmentIds,
  ) => jsonEncode([
    kind,
    conversationId,
    body,
    replyToId,
    mentions,
    attachmentIds,
  ]);
}
