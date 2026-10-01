import '../../../models.dart';
import '../../../core/http/facade_base.dart';
import 'api.dart';

mixin TopologyFacade on ApiFacadeBase {
  late final _topology = TopologyApi(transport);

  Future<ChannelTopology> topology() => _topology.topology();
}
