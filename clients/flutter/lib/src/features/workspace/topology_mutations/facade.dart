import '../../../core/http/facade_base.dart';
import '../../../models.dart';
import 'api.dart';
import 'model.dart';

mixin TopologyMutationsFacade on ApiFacadeBase {
  late final _topologyMutations = TopologyMutationsApi(transport);
  Future<TopologyCommandResult> createMemberCategory(String name, String requestId) => transport.run(() => _topologyMutations.createCategory(name, requestId));
  Future<TopologyCommandResult> createMemberChannel(String categoryId, String name, ChannelKind kind, String requestId) => transport.run(() => _topologyMutations.createChannel(categoryId, name, kind, requestId));
  Future<TopologyCommandResult> deleteMemberCategory(String id, int revision, String requestId) => transport.run(() => _topologyMutations.deleteCategory(id, revision, requestId));
  Future<TopologyCommandResult> archiveMemberText(String id, int revision, String requestId) => transport.run(() => _topologyMutations.archiveText(id, revision, requestId));
  Future<TopologyCommandResult> closeMemberVoice(String id, int revision, String requestId) => transport.run(() => _topologyMutations.closeVoice(id, revision, requestId));
}
