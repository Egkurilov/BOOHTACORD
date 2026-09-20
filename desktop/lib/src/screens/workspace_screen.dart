import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../models.dart';
import '../theme.dart';

class WorkspaceScreen extends StatelessWidget {
  const WorkspaceScreen({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1280;
        return Padding(
          padding: EdgeInsets.all(constraints.maxWidth >= 1400 ? 24 : 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: GcColors.border),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: constraints.maxWidth >= 1400 ? 312 : 264,
                    child: _Sidebar(state: state),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(child: _MainSurface(state: state)),
                  if (wide) ...[
                    const VerticalDivider(width: 1),
                    SizedBox(
                      width: constraints.maxWidth >= 1400 ? 312 : 240,
                      child: _MembersPanel(state: state),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.state});
  final AppState state;
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: GcColors.sidebar,
    child: Column(
      children: [
        const SizedBox(
          height: 72,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 22),
            child: Row(
              children: [
                _GuildMark(),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'BOOHTACORD',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Row(
            children: [
              Expanded(child: _Tab(label: 'Каналы', selected: true)),
              const SizedBox(width: 4),
              const Expanded(child: _Tab(label: 'Сообщения', selected: false)),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: state.topology == null
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: state.refreshTopology,
                  child: ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      for (final category in state.topology!.categories)
                        _Category(state: state, category: category),
                      if (state.topology!.categories.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'Каналы пока не созданы.',
                            style: TextStyle(color: GcColors.muted),
                          ),
                        ),
                    ],
                  ),
                ),
        ),
        if (state.voiceChannel != null) _VoiceDock(state: state),
        const Divider(height: 1),
        _UserFooter(state: state),
      ],
    ),
  );
}

class _GuildMark extends StatelessWidget {
  const _GuildMark();
  @override
  Widget build(BuildContext context) => Container(
    width: 34,
    height: 34,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: GcColors.raised,
      borderRadius: BorderRadius.circular(10),
    ),
    child: const Text(
      'B',
      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
    ),
  );
}

class _Tab extends StatelessWidget {
  const _Tab({required this.label, required this.selected});
  final String label;
  final bool selected;
  @override
  Widget build(BuildContext context) => Container(
    height: 36,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: selected ? GcColors.selected : Colors.transparent,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: selected ? GcColors.text : GcColors.muted,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class _Category extends StatelessWidget {
  const _Category({required this.state, required this.category});
  final AppState state;
  final ChannelCategory category;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 12, 10, 7),
          child: Text(
            category.name.toUpperCase(),
            style: const TextStyle(
              color: GcColors.muted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: .6,
            ),
          ),
        ),
        for (final channel in category.channels)
          _ChannelRow(
            channel: channel,
            selected: state.selectedChannel?.id == channel.id,
            voiceConnected: state.voiceChannel?.id == channel.id,
            onTap: () => state.selectChannel(channel),
          ),
      ],
    ),
  );
}

class _ChannelRow extends StatelessWidget {
  const _ChannelRow({
    required this.channel,
    required this.selected,
    required this.voiceConnected,
    required this.onTap,
  });
  final GuildChannel channel;
  final bool selected;
  final bool voiceConnected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: Material(
      color: selected ? GcColors.selected : Colors.transparent,
      borderRadius: BorderRadius.circular(7),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(7),
        child: SizedBox(
          height: 42,
          child: Row(
            children: [
              if (voiceConnected)
                Container(
                  width: 3,
                  height: 18,
                  decoration: BoxDecoration(
                    color: GcColors.success,
                    borderRadius: BorderRadius.circular(3),
                  ),
                )
              else
                const SizedBox(width: 3),
              const SizedBox(width: 9),
              Icon(
                channel.kind == ChannelKind.text
                    ? Icons.tag_rounded
                    : Icons.volume_up_outlined,
                size: 20,
                color: voiceConnected ? GcColors.success : GcColors.muted,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  channel.name,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected || voiceConnected
                        ? GcColors.text
                        : GcColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ),
              if (channel.admissionClosed)
                const Padding(
                  padding: EdgeInsets.only(right: 10),
                  child: Icon(
                    Icons.lock_outline,
                    size: 16,
                    color: GcColors.warning,
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _MainSurface extends StatelessWidget {
  const _MainSurface({required this.state});
  final AppState state;
  @override
  Widget build(BuildContext context) {
    final channel = state.selectedChannel;
    if (channel == null) {
      return const ColoredBox(
        color: GcColors.content,
        child: Center(
          child: Text(
            'Выберите канал',
            style: TextStyle(color: GcColors.muted),
          ),
        ),
      );
    }
    return ColoredBox(
      color: GcColors.content,
      child: channel.kind == ChannelKind.text
          ? _Conversation(state: state, channel: channel)
          : _VoiceRoom(state: state, channel: channel),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 72,
    child: DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: GcColors.border)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          children: [
            Icon(icon, color: GcColors.muted),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(color: GcColors.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    ),
  );
}

class _Conversation extends StatefulWidget {
  const _Conversation({required this.state, required this.channel});
  final AppState state;
  final GuildChannel channel;
  @override
  State<_Conversation> createState() => _ConversationState();
}

class _ConversationState extends State<_Conversation> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (await widget.state.send(_controller.text)) {
      _controller.clear();
      await Future<void>.delayed(const Duration(milliseconds: 80));
      if (_scroll.hasClients) {
        await _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      _Header(
        icon: Icons.tag_rounded,
        title: widget.channel.name,
        subtitle: 'Текстовый канал',
        trailing: IconButton(
          tooltip: 'Обновить историю',
          onPressed: () => widget.state.selectChannel(widget.channel),
          icon: const Icon(Icons.refresh),
        ),
      ),
      if (widget.state.error != null)
        _ErrorBanner(message: widget.state.error!),
      Expanded(
        child: widget.state.loadingMessages
            ? const Center(child: CircularProgressIndicator())
            : widget.state.messages.isEmpty
            ? _EmptyConversation(channel: widget.channel.name)
            : ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 24,
                ),
                itemCount: widget.state.messages.length,
                itemBuilder: (context, index) =>
                    _MessageRow(message: widget.state.messages[index]),
              ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: CallbackShortcuts(
          bindings: {const SingleActivator(LogicalKeyboardKey.enter): _send},
          child: TextField(
            controller: _controller,
            enabled: !widget.state.sending,
            maxLength: 8000,
            minLines: 1,
            maxLines: 5,
            decoration: InputDecoration(
              counterText: '',
              hintText: 'Написать сообщение…',
              prefixIcon: const Icon(Icons.add_circle_outline),
              suffixIcon: IconButton(
                tooltip: 'Отправить сообщение',
                onPressed: widget.state.sending ? null : _send,
                icon: widget.state.sending
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(
                        Icons.send_outlined,
                        color: GcColors.accentText,
                      ),
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

class _MessageRow extends StatelessWidget {
  const _MessageRow({required this.message});
  final ChatMessage message;
  @override
  Widget build(BuildContext context) {
    final initials = message.authorId
        .substring(0, message.authorId.length.clamp(1, 2))
        .toUpperCase();
    final time =
        '${message.createdAt.hour.toString().padLeft(2, '0')}:${message.createdAt.minute.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: GcColors.accent,
            child: Text(
              initials,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        message.authorId,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      time,
                      style: const TextStyle(
                        color: GcColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  message.deleted ? 'Сообщение удалено' : message.body,
                  style: TextStyle(
                    color: message.deleted ? GcColors.muted : GcColors.text,
                    fontSize: 15,
                    height: 1.45,
                    fontStyle: message.deleted
                        ? FontStyle.italic
                        : FontStyle.normal,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyConversation extends StatelessWidget {
  const _EmptyConversation({required this.channel});
  final String channel;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(36),
    child: Align(
      alignment: Alignment.bottomLeft,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(
            radius: 28,
            backgroundColor: GcColors.raised,
            child: Icon(Icons.tag_rounded, size: 30),
          ),
          const SizedBox(height: 16),
          Text(
            'Добро пожаловать в #$channel',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'Это начало истории канала.',
            style: TextStyle(color: GcColors.textSecondary),
          ),
        ],
      ),
    ),
  );
}

class _VoiceRoom extends StatelessWidget {
  const _VoiceRoom({required this.state, required this.channel});
  final AppState state;
  final GuildChannel channel;
  @override
  Widget build(BuildContext context) {
    final active = state.voiceChannel?.id == channel.id;
    return Column(
      children: [
        _Header(
          icon: Icons.volume_up_outlined,
          title: channel.name,
          subtitle: channel.admissionClosed
              ? 'Вход временно закрыт'
              : active
              ? 'Вы подключены'
              : 'Голосовой канал',
        ),
        if (state.error != null) _ErrorBanner(message: state.error!),
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 88,
                      height: 88,
                      decoration: const BoxDecoration(
                        color: GcColors.surface,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        active ? Icons.graphic_eq : Icons.headset_mic_outlined,
                        size: 42,
                        color: active ? GcColors.success : GcColors.accentText,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      active ? 'Голосовая связь установлена' : channel.name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      channel.admissionClosed
                          ? 'Администратор временно запретил новые подключения.'
                          : active
                          ? 'Управление микрофоном доступно в панели слева.'
                          : 'Подключитесь к комнате через защищённый Voice lease и LiveKit.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: GcColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 28),
                    if (!active)
                      FilledButton.icon(
                        onPressed:
                            channel.admissionClosed ||
                                state.voicePhase == VoicePhase.joining
                            ? null
                            : () => state.joinVoice(
                                channel,
                                transfer: state.transferRequired,
                              ),
                        icon: state.voicePhase == VoicePhase.joining
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.login),
                        label: Text(
                          state.transferRequired
                              ? 'Перенести подключение сюда'
                              : 'Подключиться',
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _VoiceDock extends StatelessWidget {
  const _VoiceDock({required this.state});
  final AppState state;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: const BoxDecoration(
      color: GcColors.surface,
      border: Border(top: BorderSide(color: GcColors.border)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.graphic_eq, size: 18, color: GcColors.success),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                state.voiceChannel!.name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Отключиться',
              onPressed: state.leaveVoice,
              icon: const Icon(
                Icons.call_end,
                size: 20,
                color: GcColors.danger,
              ),
            ),
          ],
        ),
        const Text(
          'Голос подключён',
          style: TextStyle(color: GcColors.success, fontSize: 12),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _VoiceButton(
                icon: state.microphoneMuted ? Icons.mic_off : Icons.mic,
                label: state.microphoneMuted ? 'Включить' : 'Микрофон',
                active: !state.microphoneMuted,
                onTap: state.toggleMicrophone,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _VoiceButton(
                icon: state.deafened ? Icons.headset_off : Icons.headphones,
                label: state.deafened ? 'Слышать' : 'Заглушить',
                active: !state.deafened,
                onTap: state.toggleDeafen,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _VoiceButton extends StatelessWidget {
  const _VoiceButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onTap,
    icon: Icon(
      icon,
      size: 17,
      color: active ? GcColors.textSecondary : GcColors.danger,
    ),
    label: Text(
      label,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 11),
    ),
    style: OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      minimumSize: const Size(0, 38),
    ),
  );
}

class _UserFooter extends StatelessWidget {
  const _UserFooter({required this.state});
  final AppState state;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 68,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 18,
            backgroundColor: Color(0xFF365ACA),
            child: Icon(Icons.person, size: 19),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state.user!.accountId,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  state.user!.isAdmin ? 'Администратор' : 'Участник',
                  style: const TextStyle(color: GcColors.muted, fontSize: 11),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Настройки аккаунта',
            onSelected: (value) {
              if (value == 'logout') state.logout();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 18),
                    SizedBox(width: 10),
                    Text('Выйти'),
                  ],
                ),
              ),
            ],
            icon: const Icon(Icons.settings_outlined, size: 20),
          ),
        ],
      ),
    ),
  );
}

class _MembersPanel extends StatelessWidget {
  const _MembersPanel({required this.state});
  final AppState state;
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: GcColors.sidebar,
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          const Text(
            'УЧАСТНИКИ',
            style: TextStyle(
              color: GcColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: .7,
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Stack(
                children: [
                  const CircleAvatar(
                    radius: 20,
                    backgroundColor: Color(0xFF365ACA),
                    child: Icon(Icons.person, size: 20),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: GcColors.success,
                        shape: BoxShape.circle,
                        border: Border.all(color: GcColors.sidebar, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.user!.accountId,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      state.voiceChannel == null
                          ? 'В сети'
                          : 'В голосовом канале',
                      style: const TextStyle(
                        color: GcColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Полный presence API пока не предусмотрен серверным контрактом.',
            style: TextStyle(color: GcColors.muted, fontSize: 12, height: 1.5),
          ),
        ],
      ),
    ),
  );
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
    color: const Color(0xFF422830),
    child: Row(
      children: [
        const Icon(Icons.error_outline, color: GcColors.danger, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(color: GcColors.danger, fontSize: 13),
          ),
        ),
      ],
    ),
  );
}
