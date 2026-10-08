import 'package:flutter/foundation.dart';

import '../../core/session/scope.dart';
import '../../features/admin/voice_timeout/model.dart';
import '../../services/api_client.dart';

class AdminVoiceTimeoutController extends ChangeNotifier {
  AdminVoiceTimeoutController(this.api, this.account)
    : ticket = api.transport.session.scope.capture(),
      server = api.transport.session.serverRevision;
  final ApiClient api;
  final String account;
  final SessionTicket ticket;
  final int server;
  VoiceTimeoutState? value;
  String? error;
  bool busy = false, disposed = false;
  int minutes = 5, sequence = 0;
  VoiceTimeoutReason reason = VoiceTimeoutReason.disruption;
  bool get active =>
      !disposed &&
      ticket.isActive &&
      server == api.transport.session.serverRevision;
  bool get canMutate => active && !busy && value != null;
  void select({int? duration, VoiceTimeoutReason? why}) {
    if (!active || busy) return;
    if (duration != null) minutes = duration;
    if (why != null) reason = why;
    notifyListeners();
  }

  Future<void> load() => run(() => api.getVoiceTimeout(account));
  Future<void> apply() async {
    if (!canMutate) return;
    if (![5, 15, 60, 240, 1440].contains(minutes)) {
      error = 'Выберите срок из списка.';
      notifyListeners();
      return;
    }
    final input = VoiceTimeoutInput(
      DateTime.now().toUtc().add(Duration(minutes: minutes)),
      reason,
    );
    await run(() => api.setVoiceTimeout(account, input));
  }

  Future<void> clear() async {
    if (!canMutate || !value!.active) return;
    await run(() => api.clearVoiceTimeout(account));
  }

  Future<void> run(Future<VoiceTimeoutState> Function() request) async {
    if (!active || busy) return;
    final own = ++sequence;
    busy = true;
    error = null;
    value = null;
    notifyListeners();
    try {
      final result = await request();
      if (active && own == sequence) value = result;
    } catch (cause) {
      if (active && own == sequence) {
        error =
            cause is ApiFailure ||
                cause is FormatException ||
                cause is ArgumentError
            ? cause.toString()
            : 'Не удалось обновить ограничение голоса.';
      }
    } finally {
      if (active && own == sequence) {
        busy = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    disposed = true;
    sequence++;
    value = null;
    error = null;
    super.dispose();
  }
}
