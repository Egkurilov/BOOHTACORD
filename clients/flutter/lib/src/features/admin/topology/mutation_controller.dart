import 'package:flutter/foundation.dart';

import '../../../models.dart';
import '../../../services/api_client.dart';
import 'actions.dart';

part 'mutation_create.dart';
part 'mutation_categories.dart';
part 'mutation_channels.dart';
part 'mutation_danger.dart';
part 'mutation_feedback.dart';

abstract class _AdminTopologyMutationBase extends ChangeNotifier {
  _AdminTopologyMutationBase({
    required this.api,
    required this.topologyProvider,
    required this.refreshTopology,
    required this.confirm,
  });
  final ApiClient api;
  final ChannelTopology? Function() topologyProvider;
  final Future<void> Function() refreshTopology;
  final TopologyConfirmationHandler confirm;
  bool busy = false;
  String? status;
  String? error;
  bool _disposed = false;

  Future<bool> validateRevision(int revision);
  Future<void> recoverStaleTopology();
  Future<void> recoverTopology(Object cause, {bool revisionBound = false});
  Future<void> mutate(
    String success,
    Future<void> Function() mutation, {
    bool revisionBound = false,
  });

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  ChannelTopology? get topology => topologyProvider();

  ChannelCategory? currentCategory(String id) =>
      topology?.categories.where((item) => item.id == id).firstOrNull;

  GuildChannel? currentChannel(String id) => topology?.categories
      .expand((item) => item.channels)
      .where((item) => item.id == id)
      .firstOrNull;

  void begin() {
    if (_disposed) return;
    busy = true;
    status = null;
    error = null;
    notifyListeners();
  }

  void finish() {
    if (_disposed) return;
    busy = false;
    notifyListeners();
  }

  void reportError(String message) {
    if (_disposed) return;
    status = null;
    error = message;
    notifyListeners();
  }
}

class AdminTopologyMutationController extends _AdminTopologyMutationBase
    with
        _TopologyFeedback,
        _TopologyCreate,
        _TopologyCategories,
        _TopologyChannels,
        _TopologyDangerActions {
  AdminTopologyMutationController({
    required super.api,
    required super.topologyProvider,
    required super.refreshTopology,
    required super.confirm,
  });

  TopologyActions get actions => TopologyActions(
    createCategory: createCategory,
    createChannel: createChannel,
    renameCategory: renameCategory,
    deleteCategory: deleteCategory,
    reorderCategory: reorderCategory,
    renameChannel: renameChannel,
    saveDescription: saveChannelDescription,
    moveChannel: moveChannel,
    reorderChannel: reorderChannel,
    archiveTextChannel: archiveTextChannel,
    closeVoiceAdmission: closeVoiceAdmission,
  );
}
