import '../native_bindings.dart';

class AdminAccountDraft {
  AdminAccountDraft({required this.role, required this.blocked});
  String role;
  bool blocked;
}

class AdminAccountConflict {
  AdminAccountConflict({required this.before});
  final AdminAccount before;
  AdminAccount? current;
}
