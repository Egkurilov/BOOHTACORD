import '../../../../../native_bindings.dart';
import '../../../../lifecycle/context.dart';

extension MemberProfilePopoverLoadFailureRenderer
    on WorkspaceMemberProfilePopoverStateContext {
  Column renderMemberProfilePopoverLoadFailure() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Semantics(
        liveRegion: true,
        child: Text(
          workspaceError!,
          style: const TextStyle(color: GcColors.danger),
        ),
      ),
      TextButton.icon(
        onPressed: workspaceLoad,
        icon: const Icon(Icons.refresh),
        label: const Text('Повторить'),
      ),
    ],
  );
}
