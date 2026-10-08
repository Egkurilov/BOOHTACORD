import '../../../../../native_bindings.dart';
import '../../../../lifecycle/context.dart';

extension MemberProfilePopoverHeaderRenderer
    on WorkspaceMemberProfilePopoverStateContext {
  Row renderMemberProfilePopoverHeader() => Row(
    children: [
      const Expanded(
        child: Text(
          'Профиль участника',
          style: TextStyle(color: GcColors.muted, fontSize: 12),
        ),
      ),
      IconButton(
        autofocus: true,
        tooltip: 'Закрыть профиль',
        visualDensity: VisualDensity.compact,
        onPressed: widget.onClose,
        icon: const Icon(Icons.close, size: 18),
      ),
    ],
  );
}
