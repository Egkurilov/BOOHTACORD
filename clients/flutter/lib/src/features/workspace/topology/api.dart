import '../../../models.dart';
import '../../../core/http/transport.dart';

class TopologyApi {
  TopologyApi(this.transport);
  final ApiTransport transport;

  Future<ChannelTopology> topology() async {
    final data = await transport.checked(
      await transport.client.get(
        transport.uri('/channels'),
        headers: await transport.headers(),
      ),
    ) as Map<String, dynamic>;
    return ChannelTopology.fromJson(data);
  }
}
