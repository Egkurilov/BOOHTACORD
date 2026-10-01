import 'package:flutter/foundation.dart';

import '../../../core/session/scope.dart';
import '../../../models.dart';
import '../../../services/api_client.dart';

export 'refresh.dart';
export 'edit.dart';
export 'avatar.dart';

class ProfileController extends ChangeNotifier {
  ProfileController(
    this.api,
    this.scope, {
    required this.error,
    required this.refreshMembers,
    this.formatError,
  });
  final ApiClient api;
  final SessionScope scope;
  final void Function(String?) error;
  final String Function(Object)? formatError;
  final Future<void> Function() refreshMembers;
  OwnProfile? profile;
  bool profileLoading = false;
  bool profileSaving = false;
  String? profileLoadError;
  int avatarRevision = 0;
  int revision = 0;
  bool disposed = false;

  bool accepts(SessionTicket ticket, int request) =>
      !disposed && ticket.isActive && revision == request;
  void changed() {
    if (!disposed) notifyListeners();
  }

  String message(Object cause) =>
      formatError?.call(cause) ??
      (cause is ApiFailure
          ? cause.message
          : 'Не удалось выполнить действие: ${cause.runtimeType}.');

  void clear() {
    revision++;
    profile = null;
    profileLoading = false;
    profileSaving = false;
    profileLoadError = null;
    avatarRevision = 0;
  }

  Future<bool> save(Future<void> Function(bool Function()) operation) async {
    final ticket = scope.capture();
    if (disposed || !ticket.isActive) return false;
    final request = revision;
    bool active() => accepts(ticket, request);
    profileSaving = true;
    error(null);
    changed();
    try {
      await operation(active);
      return active();
    } catch (cause) {
      if (active()) error(message(cause));
      return false;
    } finally {
      if (active()) {
        profileSaving = false;
        changed();
      }
    }
  }

  @override
  void dispose() {
    disposed = true;
    clear();
    super.dispose();
  }
}
