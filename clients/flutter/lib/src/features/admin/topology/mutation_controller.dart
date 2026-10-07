import 'package:flutter/material.dart';

import '../../../models.dart';
import '../../../services/api_client.dart';
import '../../../core/ui/confirmation_dialog.dart';
import 'actions.dart';

part 'mutation_create.dart';
part 'mutation_categories.dart';
part 'mutation_channels.dart';
part 'mutation_danger.dart';
part 'mutation_feedback.dart';

abstract class _AdminTopologyMutationBase extends ChangeNotifier {
  _AdminTopologyMutationBase({
    required this.api,
    required this.currentTopology,
    required this.refreshTopology,
    required this.contextProvider,
  });
  final ApiClient api;
  final ChannelTopology? Function() currentTopology;
  final Future<void> Function() refreshTopology;
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
      currentTopology()?.categories.where((item) => item.id == id).firstOrNull;

  GuildChannel? currentChannel(String id) => currentTopology()?.categories
      .expand((item) => item.channels)
      .where((item) => item.id == id)
      .firstOrNull;

  void _begin() {
    if (_disposed) return;
    busy = true;
    status = null;
    error = null;
    notifyListeners();
  }

  void _finish() {
    if (_disposed) return;
    busy = false;
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
    required super.currentTopology,
    required super.refreshTopology,
    required super.contextProvider,
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
