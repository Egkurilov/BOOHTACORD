import 'controller.dart';
import '../../../features/conversation/reactions/api.dart';
import '../../../features/conversation/pins/api.dart';
import '../../../features/realtime/social_hints/hints.dart';

extension MessageSocialCommands on MessageSocialController {
  Future<void> toggle(String emoji) async {
    if (!active || busy || loading || error != null) return;
    final present = !mine(emoji);
    busy = true;
    error = null;
    changed();
    try {
      await ReactionApi(transport)
          .set(direct, conversation, message, emoji, present);
      if (active) await load();
    } catch (cause) {
      if (active) error = cause.toString();
    } finally {
      if (active) {
        busy = false;
        changed();
      }
    }
  }

  Future<void> pin() async {
    if (!active || direct || !canPin || busy) return;
    busy = true;
    notice = null;
    error = null;
    changed();
    try {
      await TextPinApi(transport).set(conversation, message, true);
      if (active) {
        notice = 'Сообщение закреплено.';
        SocialHints.forTransport(transport)
            .emit(SocialHint(false, conversation, message, true));
      }
    } catch (cause) {
      if (active) error = cause.toString();
    } finally {
      if (active) {
        busy = false;
        changed();
      }
    }
  }
}
