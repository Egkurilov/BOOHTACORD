import '../composition/owners.dart';

mixin AppErrorsAccess on AppOwners {
  void reportError(String message) {
    error = message;
    notifyListeners();
  }

  void clearError() {
    if (error == null) return;
    error = null;
    notifyListeners();
  }
}
