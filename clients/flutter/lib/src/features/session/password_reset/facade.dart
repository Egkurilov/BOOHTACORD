import '../../../core/http/facade_base.dart';
import 'api.dart';

mixin PasswordResetFacade on ApiFacadeBase {
  late final _passwordReset = PasswordResetApi(transport);

  Future<void> completePasswordReset(String token, String password) =>
      _passwordReset.completePasswordReset(token, password);
}
