import '../composer_actions/handler.dart';
import '../../../message_context_menu/component.dart';
import '../../../native_bindings.dart';
import '../../lifecycle/context.dart';

extension ConversationComposeTextRenderer on WorkspaceConversationStateContext {
  CallbackShortcuts renderConversationComposeText(
    bool compact,
    BorderRadius composerBorderRadius,
    bool compactComposerActions,
  ) => CallbackShortcuts(
    bindings: {
      const SingleActivator(LogicalKeyboardKey.enter): workspaceSend,
      const SingleActivator(LogicalKeyboardKey.keyV, control: true):
          workspacePasteFromClipboard,
      const SingleActivator(LogicalKeyboardKey.keyV, meta: true):
          workspacePasteFromClipboard,
      const SingleActivator(LogicalKeyboardKey.insert, shift: true):
          workspacePasteFromClipboard,
    },
    child: TextField(
      focusNode: workspaceComposerFocus,
      controller: workspaceController,
      contextMenuBuilder: (context, editableTextState) =>
          workspaceMessageContextMenu(
            context,
            editableTextState,
            workspacePasteFromClipboard,
          ),
      enabled: !widget.state.sending,
      maxLength: 8000,
      textInputAction: TextInputAction.send,
      minLines: 1,
      maxLines: 5,
      onSubmitted: (_) => workspaceSend(),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: GcColors.raised,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        constraints: BoxConstraints(minHeight: compact ? 54 : 52),
        border: OutlineInputBorder(
          borderRadius: composerBorderRadius,
          borderSide: const BorderSide(color: GcColors.control),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: composerBorderRadius,
          borderSide: const BorderSide(color: GcColors.control),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: composerBorderRadius,
          borderSide: const BorderSide(color: GcColors.focus, width: 2),
        ),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 44,
          minHeight: 44,
        ),
        counterText: '',
        hintText: 'Написать сообщение…',
        prefixIcon: renderConversationComposerActions(compactComposerActions),
        suffixIcon: IconButton(
          tooltip: 'Отправить сообщение',
          onPressed: widget.state.sending || workspaceAttachmentsPending
              ? null
              : workspaceSend,
          icon: widget.state.sending
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send_outlined, color: GcColors.accentText),
        ),
      ),
    ),
  );
}
