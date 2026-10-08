import '../../native_bindings.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceScreenStateWorkspaceHandleVoiceShortcutBinding
    on WorkspaceScreenStateContext {
  @override
  bool workspaceHandleVoiceShortcut(KeyDownEvent event) {
    return executeWorkspaceScreenStateWorkspaceHandleVoiceShortcut(event);
  }
}

extension WorkspaceScreenStateWorkspaceHandleVoiceShortcutAction
    on WorkspaceScreenStateContext {
  bool executeWorkspaceScreenStateWorkspaceHandleVoiceShortcut(
    KeyDownEvent event,
  ) {
    if (kIsWeb ||
        !workspaceShortcutAvailability.enabled(
          mobile: widget.state.usesTouchPushToTalk,
        ) ||
        ModalRoute.of(context)?.isCurrent == false ||
        shortcutFocusBlocked()) {
      return false;
    }
    if (widget.state.pushToTalkKeyId == event.logicalKey.keyId) return false;
    final keyboard = HardwareKeyboard.instance;
    final action =
        widget.state.microphoneShortcut?.matches(event, keyboard) == true
        ? 'microphone'
        : widget.state.deafenShortcut?.matches(event, keyboard) == true
        ? 'deafen'
        : null;
    if (action == null) return false;
    unawaited(widget.state.voice.runVoiceShortcut(action));
    return true;
  }
}
