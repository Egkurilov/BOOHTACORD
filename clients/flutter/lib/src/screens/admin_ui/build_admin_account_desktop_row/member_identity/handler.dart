import '../../native_bindings.dart';
import '../../lifecycle/context.dart';

extension RenderAdminMemberIdentityAction on AdminScreenStateContext {
  List<Widget> renderAdminMemberIdentity(
    Color avatarColor,
    String initials,
    AdminAccount account,
  ) => [
    CircleAvatar(
      radius: 20,
      backgroundColor: avatarColor,
      child: Text(
        initials,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    const SizedBox(width: 12),
    Expanded(
      flex: 5,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            account.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Text(
            '@${account.login}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: GcColors.textSecondary, fontSize: 12),
          ),
        ],
      ),
    ),
    const SizedBox(width: 12),
  ];
}
