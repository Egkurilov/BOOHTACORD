import 'package:flutter/foundation.dart';

import '../../../services/api_client.dart';
import '../../../services/password_reset_link.dart';
export 'complete.dart';

class PasswordResetController extends ChangeNotifier {
  PasswordResetController(
    this.api, {
    required this.clearError,
    required this.message,
  });
  final ApiClient api;
  final void Function() clearError;
  final String Function(Object) message;
  bool resetRoute = false;
  String? resetToken;
  bool resetPending = false;
  bool resetCompleted = false;
  bool resetUnusable = false;
  String? resetError;
  bool focusLoginOnMount = false;
  int revision = 0;
  bool disposed = false;
  void changed() {
    if (!disposed) notifyListeners();
  }

  void cancelOperations() {
    revision++;
    resetPending = false;
  }

  void openPasswordResetLink(String value) {
    cancelOperations();
    resetToken = parsePasswordResetToken(api.baseUrl, value);
    resetRoute = true;
    resetCompleted = false;
    resetUnusable = resetToken == null;
    resetError = resetUnusable
        ? 'Ссылка недействительна или срок её действия истёк. Попросите администратора выдать новую ссылку.'
        : null;
    clearError();
    changed();
  }

  void returnToLogin() {
    cancelOperations();
    resetRoute = false;
    resetToken = null;
    resetCompleted = false;
    resetUnusable = false;
    resetError = null;
    focusLoginOnMount = true;
    clearError();
    changed();
  }

  @override
  void dispose() {
    disposed = true;
    cancelOperations();
    resetToken = null;
    super.dispose();
  }
}
