import '../../conversation/lifecycle/controller.dart';

extension ConversationEditText on ConversationController {
  Future<bool> editText(ChatMessage message, String body) async =>
      (await editTextWithResult(message, body, message.revision)).kind ==
      MessageEditStatus.saved;
}
