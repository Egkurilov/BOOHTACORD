import 'package:flutter/material.dart';

import '../../../app_state.dart';
import '../../../models.dart';
import '../../../services/api_client.dart';
import '../../../widgets/confirmation_dialog.dart';
import 'actions.dart';

part 'mutation_create.dart';
part 'mutation_categories.dart';
part 'mutation_channels.dart';
part 'mutation_danger.dart';
part 'mutation_feedback.dart';

abstract class _AdminTopologyMutationBase extends ChangeNotifier {
  _AdminTopologyMutationBase(this.state, this.contextProvider);
  final AppState state;
  final BuildContext Function() contextProvider;
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

  ChannelCategory? currentCategory(String id) =>
      state.topology?.categories.where((item) => item.id == id).firstOrNull;

  GuildChannel? currentChannel(String id) => state.topology?.categories
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
  AdminTopologyMutationController(super.state, super.contextProvider);

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
