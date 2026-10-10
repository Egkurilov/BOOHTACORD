import '../native_bindings.dart';
import '../lifecycle/context.dart';

import 'package:http/http.dart' as http;

String rolePermissionsFailureMessage(Object cause) {
  if (cause is ApiFailure) {
    if (cause.status == 401) {
      return 'Сессия завершена. Войдите снова.';
    }
    if (cause.status == 403) {
      return 'Нет доступа к изменению разрешений этой роли.';
    }
    if (cause.status == 404) {
      return 'Роль не найдена. Обновите данные и повторите попытку.';
    }
    if (cause.status == 429) {
      return 'Слишком много запросов. Подождите немного и повторите попытку.';
    }
    if (cause.status != null && cause.status! >= 500) {
      return 'Сервис временно не отвечает. Попробуйте позже.';
    }
    return cause.message;
  }
  if (cause is http.ClientException) {
    return 'Нет соединения с сервером. Проверьте подключение.';
  }
  if (cause is TimeoutException) {
    return 'Сервер не ответил вовремя. Повторите попытку.';
  }
  return cause.toString();
}

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
