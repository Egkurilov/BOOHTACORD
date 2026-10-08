import '../../../native_bindings.dart';
import '../../../text_pins/component.dart';
import '../../lifecycle/context.dart';
import '../header_controls/handler.dart';

extension TextPinsRenderer on WorkspaceWorkspaceSearchPanelStateContext {
  Widget renderTextPinsPanel(bool compact, String channel) => Material(
    color: GcColors.sidebar,
    child: Column(
      children: [
        renderWorkspaceSearchPanelHeaderControls(compact, compact ? 16 : 20),
        Expanded(
          child: TextPinsPanel(
            transport: state.api.transport,
            channel: channel,
            onOpen: (pin) {
              state.openSearchContext(
                SearchMessage(
                  id: pin.messageId,
                  kind: SearchMessageKind.channel,
                  conversationId: channel,
                  authorId: pin.authorId,
                  body: pin.preview,
                  createdAt: pin.createdAt,
                  revision: 1,
                ),
                heading: 'Закреплённое сообщение',
              );
            },
          ),
        ),
      ],
    ),
  );
}
