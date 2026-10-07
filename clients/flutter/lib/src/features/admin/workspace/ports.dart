import 'package:flutter/foundation.dart' show VoidCallback;

import '../../../models.dart';
import '../../../services/api_client.dart';

class AdminWorkspacePorts {
  const AdminWorkspacePorts({
    required this.api,
    required this.topology,
    required this.refreshTopology,
    required this.refreshGuildProfile,
    required this.refreshPermissions,
    required this.closePanel,
    required this.currentAccountId,
    required this.voiceParticipantIds,
  });

  final ApiClient api;
  final ChannelTopology? Function() topology;
  final Future<void> Function() refreshTopology;
  final Future<void> Function() refreshGuildProfile;
  final Future<void> Function() refreshPermissions;
  final VoidCallback closePanel;
  final String? Function() currentAccountId;
  final Set<String> Function() voiceParticipantIds;
}
