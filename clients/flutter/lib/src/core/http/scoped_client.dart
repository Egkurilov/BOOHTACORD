import 'package:http/http.dart' as http;

import '../session/scope.dart';
import 'request_scope.dart';

class ScopedHttpClient extends http.BaseClient {
  ScopedHttpClient(this.inner, this.scope);
  final http.Client inner;
  final SessionScope scope;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final admission = RequestScope.current ?? RequestScope(scope.capture());
    admission.ensureCurrent();
    final response = await inner.send(request);
    if (!admission.active) {
      await response.stream.listen(null).cancel();
      admission.ensureCurrent();
    }
    return response;
  }

  @override
  void close() => inner.close();
}
