import 'controller.dart';

extension ProfileRefresh on ProfileController {
  Future<void> refreshProfile() async {
    final ticket = scope.capture();
    if (disposed || !ticket.isActive) return;
    final request = revision;
    profileLoading = true;
    profileLoadError = null;
    changed();
    try {
      final result = await api.ownProfile();
      if (accepts(ticket, request)) profile = result;
    } catch (cause) {
      if (accepts(ticket, request)) profileLoadError = message(cause);
    } finally {
      if (accepts(ticket, request)) {
        profileLoading = false;
        changed();
      }
    }
  }
}
