import 'package:http/http.dart' as http;

import 'transport.dart';

abstract class ApiFacadeBase {
  ApiFacadeBase({http.Client? client})
    : transport = ApiTransport(client: client);
  final ApiTransport transport;
  String get baseUrl => transport.session.baseUrl;
  set baseUrl(String value) => transport.session.baseUrl = value;
  void Function()? get onUnauthorized => transport.session.onUnauthorized;
  set onUnauthorized(void Function()? value) =>
      transport.session.onUnauthorized = value;
  bool get realtimeEnabled => true;
  Future<void> initialize() => transport.session.initialize();
  Future<void> setBaseUrl(String value) => transport.session.setBaseUrl(value);
}
