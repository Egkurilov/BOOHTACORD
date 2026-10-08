import 'package:flutter/material.dart';

import '../../../models.dart';
import '../../../services/api_client.dart';
import 'lifecycle/state.dart';

class AdminGuildSettings extends StatefulWidget {
  const AdminGuildSettings({
    super.key,
    required this.api,
    required this.channels,
    required this.onSaved,
  });
  final ApiClient api;
  final List<GuildChannel> channels;
  final Future<void> Function() onSaved;
  @override
  State<AdminGuildSettings> createState() => AdminGuildSettingsState();
}
