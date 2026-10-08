import 'column/handler.dart';
import '../../../native_bindings.dart';
import '../../lifecycle/context.dart';

extension MemberProfilePopoverProfileContentRenderer
    on WorkspaceMemberProfilePopoverStateContext {
  Column renderMemberProfilePopoverProfileContent(
    bool canMessage,
    bool canKick,
    RemoteParticipant? participant,
    BuildContext context,
  ) => renderMemberProfilePopoverColumn(
    canMessage,
    canKick,
    participant,
    context,
  );
}
