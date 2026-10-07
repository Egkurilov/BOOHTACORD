import 'package:flutter/material.dart';

import '../../../models.dart';
import '../../../services/api_client.dart';
import 'controller.dart';
import 'welcome_selector.dart';

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
  State<AdminGuildSettings> createState() => _AdminGuildSettingsState();
}

class _AdminGuildSettingsState extends State<AdminGuildSettings> {
  late final state = GuildSettingsController(
    widget.api.readGuildSettings,
    widget.api.updateGuildSettings,
  );
  final name = TextEditingController();
  @override
  void initState() {
    super.initState();
    state.addListener(_changed);
    _load();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    await state.load();
    if (mounted) name.text = state.name;
  }

  Future<void> _save() async {
    state.name = name.text;
    await state.save(_channels.map((channel) => channel.id).toList());
    if (mounted && state.saved) {
      name.text = state.name;
      await widget.onSaved();
    }
  }

  List<GuildChannel> get _channels => widget.channels
      .where(
        (channel) =>
            channel.kind == ChannelKind.text && !channel.admissionClosed,
      )
      .toList();
  @override
  void dispose() {
    state.dispose();
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < 840;
      return ListView(
        padding: EdgeInsets.fromLTRB(compact ? 0 : 24, 0, compact ? 0 : 24, 24),
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: compact ? double.infinity : 600,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Гильдия',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: name,
                  enabled: !state.busy && state.revision > 0,
                  decoration: const InputDecoration(
                    labelText: 'Название гильдии',
                    helperText: 'Название показывается участникам и на экране входа. От 1 до 80 символов, без переводов строк.',
                  ),
                ),
                const SizedBox(height: 24),
                WelcomeSelector(
                  value: state.welcome,
                  channels: _channels,
                  revision: state.revision,
                  busy: state.busy,
                  onChanged: (value) => setState(() => state.welcome = value),
                ),
                if (state.error != null)
                  Semantics(liveRegion: true, child: Text(state.error!)),
                if (state.saved)
                  Semantics(
                    liveRegion: true,
                    child: const Text('Настройки сохранены.'),
                  ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: state.busy || state.revision == 0 ? null : _save,
                  child: Text(state.busy ? 'Сохраняем…' : 'Сохранить'),
                ),
                if (state.revision == 0 && !state.busy)
                  TextButton(
                    onPressed: _load,
                    child: const Text('Загрузить настройки'),
                  ),
              ],
            ),
          ),
        ],
      );
    },
  );
}
