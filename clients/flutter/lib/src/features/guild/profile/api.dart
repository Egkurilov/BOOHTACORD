import 'dart:convert';

import '../../../core/http/transport.dart';
import '../../../core/http/api_failure.dart';
import 'model.dart';

class GuildProfileApi {
  GuildProfileApi(this.transport);
  final ApiTransport transport;
  Future<GuildProfile> read() async {
    final response = await transport.client.get(
      transport.uri('/guild-profile'),
      headers: {...transport.publicHeaders(), 'cache-control': 'no-store'},
    );
    transport.ensureCurrent();
    if (response.statusCode != 200) {
      throw ApiFailure(
        'Не удалось загрузить название гильдии.',
        status: response.statusCode,
      );
    }
    return GuildProfile.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }
}
