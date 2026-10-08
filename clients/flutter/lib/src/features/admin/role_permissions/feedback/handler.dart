import '../native_bindings.dart';
import '../lifecycle/context.dart';

extension RoleFeedbackAction on RolePermissionsContext {
  List<Widget> executeRenderRoleFeedback() => [
    if (role == GuildRole.member && dirty)
      Padding(
        padding: EdgeInsets.only(top: 8),
        child: Semantics(
          liveRegion: true,
          label: 'Есть несохранённые изменения',
          child: Text(
            'Есть несохранённые изменения',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ),
    if (status != null)
      Semantics(
        liveRegion: true,
        child: Text(status!, style: const TextStyle(color: Colors.green)),
      ),
    if (error != null)
      Semantics(
        liveRegion: true,
        child: Text(error!, style: const TextStyle(color: Colors.red)),
      ),
    if (conflict && conflictBefore != null && conflictCurrent != null)
      RolePermissionsConflictReview(
        before: conflictBefore!,
        current: conflictCurrent!,
        proposed: draft,
        busy: saving || loading,
        onRefresh: () => loadRoles(reset: false),
        onAcceptCurrent: () => mutate(() {
          baseline = Map.of(conflictCurrent!);
          draft = Map.of(conflictCurrent!);
          conflict = false;
          conflictBefore = null;
          conflictCurrent = null;
          error = null;
          status = 'Серверные значения приняты в черновик.';
        }),
        onKeepDraft: () => mutate(() {
          baseline = Map.of(conflictCurrent!);
          conflict = false;
          conflictBefore = null;
          conflictCurrent = null;
          error = null;
          status = 'Черновик сохранён. Нажмите «Сохранить» ещё раз.';
        }),
      ),
  ];
}
