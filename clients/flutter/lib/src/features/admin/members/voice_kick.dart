import 'state.dart';

mixin AdminMembersVoiceKick on AdminMembersState {
  Future<void> kickVoiceParticipant(String id) async {
    if (busyAccountIds.contains(id)) return;
    busyAccountIds.add(id);
    status = null;
    error = null;
    emit();
    try {
      final revoked = await api.kickAdminVoiceParticipant(id);
      status = revoked > 0
          ? 'Подключение отозвано.'
          : 'Активное голосовое подключение не найдено.';
    } catch (cause) {
      error = cause.toString();
    } finally {
      busyAccountIds.remove(id);
      emit();
    }
  }
}
