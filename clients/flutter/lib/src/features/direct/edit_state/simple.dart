import '../../conversation/lifecycle/controller.dart';

extension ConversationEditDirect on ConversationController {
  Future<bool> editDirect(DirectChatMessage message, String body) async =>
      (await editDirectWithResult(message, body, message.revision)).kind ==
      MessageEditStatus.saved;
}
