import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:livekit_client/livekit_client.dart' hide ChatMessage;

import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import 'profile_screen.dart';

class WorkspaceScreen extends StatefulWidget {
  const WorkspaceScreen({super.key, required this.state});
  final AppState state;

  @override
  State<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends State<WorkspaceScreen> {
  bool _showMobileSidebar = true;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 720;
          final wide = constraints.maxWidth >= 1280;
          final content = compact
              ? _showMobileSidebar
                    ? _Sidebar(
                        state: widget.state,
                        onChannelSelected: () =>
                            setState(() => _showMobileSidebar = false),
                      )
                    : _MainSurface(
                        state: widget.state,
                        onBack: () => setState(() => _showMobileSidebar = true),
                      )
              : Row(
                  children: [
                    SizedBox(
                      width: constraints.maxWidth >= 1400 ? 312 : 264,
                      child: _Sidebar(state: widget.state),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(child: _MainSurface(state: widget.state)),
                    if (wide &&
                        widget.state.workspacePanel == WorkspacePanel.none &&
                        widget.state.selectedDirectMessage == null) ...[
                      const VerticalDivider(width: 1),
                      SizedBox(
                        width: constraints.maxWidth >= 1400 ? 312 : 240,
                        child: _MembersPanel(state: widget.state),
                      ),
                    ],
                  ],
                );
          return Padding(
            padding: compact
                ? EdgeInsets.zero
                : EdgeInsets.all(constraints.maxWidth >= 1400 ? 24 : 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(compact ? 0 : 16),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: compact ? null : Border.all(color: GcColors.border),
                ),
                child: content,
              ),
            ),
          );
        },
      ),
    ),
  );
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.state, this.onChannelSelected});
  final AppState state;
  final VoidCallback? onChannelSelected;
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: GcColors.sidebar,
    child: Column(
      children: [
        SizedBox(
          height: 72,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Row(
              children: [
                const _GuildMark(),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Моя гильдия',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  tooltip: 'Участники',
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => SafeArea(
                      child: SizedBox(
                        height: MediaQuery.sizeOf(context).height * .72,
                        child: _MembersPanel(state: state),
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.people_outline),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: _Tab(
                  label: 'Каналы',
                  selected:
                      state.navigationSection == NavigationSection.channels,
                  onTap: state.showChannels,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _Tab(
                  label: 'Личные',
                  selected:
                      state.navigationSection ==
                      NavigationSection.directMessages,
                  onTap: state.showDirectMessages,
                ),
              ),
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
                      if (state.navigationSection == NavigationSection.channels)
                        for (final category in state.topology!.categories)
                          _Category(
                            state: state,
                            category: category,
                            onChannelSelected: onChannelSelected,
                          )
                      else
                        _DirectMessageNavigation(
                          state: state,
                          onSelected: onChannelSelected,
                        ),
                      if (state.navigationSection ==
                              NavigationSection.channels &&
                          state.topology!.categories.isEmpty)
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
      'G',
      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
    ),
  );
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: selected ? GcColors.selected : Colors.transparent,
    borderRadius: BorderRadius.circular(6),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        height: 36,
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? GcColors.text : GcColors.muted,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    ),
  );
}

class _DirectMessageNavigation extends StatelessWidget {
  const _DirectMessageNavigation({required this.state, this.onSelected});
  final AppState state;
  final VoidCallback? onSelected;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          const Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Text(
                'ЛИЧНЫЕ СООБЩЕНИЯ',
                style: TextStyle(
                  color: GcColors.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          PopupMenuButton<DirectCandidate>(
            tooltip: 'Начать диалог',
            onSelected: (candidate) async {
              await state.createDirectConversation(candidate);
              onSelected?.call();
            },
            itemBuilder: (_) => state.directMessageCandidates
                .map(
                  (candidate) => PopupMenuItem(
                    value: candidate,
                    child: Text(candidate.displayName),
                  ),
                )
                .toList(growable: false),
            icon: const Icon(Icons.add_comment_outlined, size: 19),
          ),
        ],
      ),
      for (final conversation in state.directMessages)
        ListTile(
          selected: state.selectedDirectMessage?.id == conversation.id,
          leading: const CircleAvatar(child: Icon(Icons.person, size: 18)),
          title: Text(
            conversation.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: conversation.unreadCount > 0
              ? Badge(label: Text('${conversation.unreadCount}'))
              : null,
          onTap: () async {
            await state.openDirectConversation(conversation);
            onSelected?.call();
          },
        ),
      if (state.directMessages.isEmpty)
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Диалогов пока нет. Нажмите +, чтобы начать.',
            style: TextStyle(color: GcColors.muted, fontSize: 12),
          ),
        ),
    ],
  );
}

class _Category extends StatelessWidget {
  const _Category({
    required this.state,
    required this.category,
    this.onChannelSelected,
  });
  final AppState state;
  final ChannelCategory category;
  final VoidCallback? onChannelSelected;
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
            onTap: () {
              state.selectChannel(channel);
              onChannelSelected?.call();
            },
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
  const _MainSurface({required this.state, this.onBack});
  final AppState state;
  final VoidCallback? onBack;
  @override
  Widget build(BuildContext context) {
    if (state.workspacePanel == WorkspacePanel.profile) {
      return ProfileScreen(state: state);
    }
    final direct = state.selectedDirectMessage;
    if (direct != null) {
      return ColoredBox(
        color: GcColors.content,
        child: _DirectConversation(
          state: state,
          conversation: direct,
          onBack: onBack,
        ),
      );
    }
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
          ? _Conversation(state: state, channel: channel, onBack: onBack)
          : _VoiceRoom(state: state, channel: channel, onBack: onBack),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onBack,
    this.trailing,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onBack;
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
            if (onBack != null) ...[
              IconButton(
                tooltip: 'К списку каналов',
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              const SizedBox(width: 4),
            ],
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
  const _Conversation({
    required this.state,
    required this.channel,
    this.onBack,
  });
  final AppState state;
  final GuildChannel channel;
  final VoidCallback? onBack;
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
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Header(
          icon: Icons.tag_rounded,
          title: widget.channel.name,
          subtitle: 'Текстовый канал',
          onBack: widget.onBack,
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
                  itemBuilder: (context, index) => _MessageRow(
                    state: widget.state,
                    message: widget.state.messages[index],
                  ),
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
}

class _MessageRow extends StatelessWidget {
  const _MessageRow({required this.state, required this.message});
  final AppState state;
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
                    if (!message.deleted &&
                        (message.authorId == state.user?.accountId ||
                            state.user?.isAdmin == true))
                      PopupMenuButton<String>(
                        tooltip: 'Действия с сообщением',
                        onSelected: (action) async {
                          if (action == 'edit') {
                            final body = await _editMessageDialog(
                              context,
                              message.body,
                            );
                            if (body != null) {
                              await state.editText(message, body);
                            }
                            return;
                          }
                          if (action == 'delete' &&
                              await _confirmDelete(context)) {
                            await state.deleteText(message);
                          }
                        },
                        itemBuilder: (_) => [
                          if (message.authorId == state.user?.accountId)
                            const PopupMenuItem(
                              value: 'edit',
                              child: Text('Изменить'),
                            ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Удалить'),
                          ),
                        ],
                        icon: const Icon(Icons.more_horiz, size: 18),
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

class _DirectConversation extends StatefulWidget {
  const _DirectConversation({
    required this.state,
    required this.conversation,
    this.onBack,
  });
  final AppState state;
  final DirectConversation conversation;
  final VoidCallback? onBack;

  @override
  State<_DirectConversation> createState() => _DirectConversationState();
}

class _DirectConversationState extends State<_DirectConversation> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (await widget.state.sendDirect(_controller.text)) _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.state.loadingDirectMessages &&
        widget.state.directMessageHistory.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.state.markSelectedDirectMessageRead();
      });
    }
    return Column(
      children: [
        _Header(
          icon: Icons.person_outline,
          title: widget.conversation.displayName,
          subtitle: 'Личные сообщения',
          onBack: widget.onBack,
          trailing: IconButton(
            tooltip: 'Обновить диалог',
            onPressed: () =>
                widget.state.openDirectConversation(widget.conversation),
            icon: const Icon(Icons.refresh),
          ),
        ),
        if (widget.state.error != null)
          _ErrorBanner(message: widget.state.error!),
        Expanded(
          child: widget.state.loadingDirectMessages
              ? const Center(child: CircularProgressIndicator())
              : widget.state.directMessageHistory.isEmpty
              ? Center(
                  child: Text(
                    'Начните диалог с ${widget.conversation.displayName}',
                    style: const TextStyle(color: GcColors.muted),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 24,
                  ),
                  itemCount: widget.state.directMessageHistory.length,
                  itemBuilder: (context, index) {
                    final message = widget.state.directMessageHistory[index];
                    final own =
                        message.authorId == widget.state.user?.accountId;
                    return Row(
                      mainAxisAlignment: own
                          ? MainAxisAlignment.end
                          : MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          constraints: const BoxConstraints(maxWidth: 560),
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 11,
                          ),
                          decoration: BoxDecoration(
                            color: own ? GcColors.selected : GcColors.surface,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            message.deleted
                                ? 'Сообщение удалено'
                                : message.body,
                            style: TextStyle(
                              color: message.deleted
                                  ? GcColors.muted
                                  : GcColors.text,
                              fontStyle: message.deleted
                                  ? FontStyle.italic
                                  : FontStyle.normal,
                            ),
                          ),
                        ),
                        if (own && !message.deleted)
                          PopupMenuButton<String>(
                            tooltip: 'Действия с сообщением',
                            onSelected: (action) async {
                              if (action == 'edit') {
                                final body = await _editMessageDialog(
                                  context,
                                  message.body,
                                );
                                if (body != null) {
                                  await widget.state.editDirect(message, body);
                                }
                                return;
                              }
                              if (action == 'delete' &&
                                  await _confirmDelete(context)) {
                                await widget.state.deleteDirect(message);
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'edit',
                                child: Text('Изменить'),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('Удалить'),
                              ),
                            ],
                            icon: const Icon(Icons.more_horiz, size: 18),
                          ),
                      ],
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: TextField(
            controller: _controller,
            enabled: !widget.state.sending,
            maxLength: 8000,
            minLines: 1,
            maxLines: 5,
            onSubmitted: (_) => _send(),
            decoration: InputDecoration(
              counterText: '',
              hintText: 'Сообщение для ${widget.conversation.displayName}…',
              suffixIcon: IconButton(
                tooltip: 'Отправить личное сообщение',
                onPressed: widget.state.sending ? null : _send,
                icon: const Icon(Icons.send_outlined),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _VoiceRoom extends StatefulWidget {
  const _VoiceRoom({required this.state, required this.channel, this.onBack});
  final AppState state;
  final GuildChannel channel;
  final VoidCallback? onBack;

  @override
  State<_VoiceRoom> createState() => _VoiceRoomState();
}

class _VoiceRoomState extends State<_VoiceRoom> {
  String? _selectedScreenIdentity;

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final channel = widget.channel;
    final room = state.room;
    final active = state.voiceChannel?.id == channel.id;
    return AnimatedBuilder(
      animation: room ?? state,
      builder: (context, _) {
        final participants =
            room?.remoteParticipants.values.toList() ?? const [];
        final screens = participants
            .where(
              (participant) => participant.videoTrackPublications.any(
                (publication) =>
                    publication.source == TrackSource.screenShareVideo &&
                    publication.track != null,
              ),
            )
            .toList(growable: false);
        final selectedScreen = screens
            .where(
              (participant) => participant.identity == _selectedScreenIdentity,
            )
            .firstOrNull;
        final selectedTrack = selectedScreen?.videoTrackPublications
            .where(
              (publication) =>
                  publication.source == TrackSource.screenShareVideo,
            )
            .firstOrNull
            ?.track;
        final participantCount = active ? participants.length + 1 : 0;
        final selectedName = selectedScreen == null
            ? null
            : _participantName(selectedScreen);
        return Column(
          children: [
            _Header(
              icon: Icons.volume_up_outlined,
              title: channel.name,
              onBack: widget.onBack,
              subtitle: selectedName != null
                  ? 'Демонстрация $selectedName'
                  : active
                  ? 'Голосовой канал · участников: $participantCount'
                  : channel.admissionClosed
                  ? 'Вход временно закрыт'
                  : 'Голосовой канал · подключитесь, чтобы увидеть участников',
            ),
            Expanded(
              child: active
                  ? selectedTrack != null
                        ? _VoiceScreenViewer(
                            track: selectedTrack,
                            publisherName: selectedName!,
                            screens: screens,
                            selectedIdentity: _selectedScreenIdentity,
                            localName:
                                state.profile?.displayName.trim().isNotEmpty ==
                                    true
                                ? state.profile!.displayName
                                : 'Вы',
                            localMuted: state.microphoneMuted,
                            localSpeaking:
                                room?.localParticipant?.isSpeaking ?? false,
                            participants: participants,
                            onClose: () =>
                                setState(() => _selectedScreenIdentity = null),
                            onScreenSelected: (identity) => setState(
                              () => _selectedScreenIdentity = identity,
                            ),
                          )
                        : _VoiceParticipantRoom(
                            state: state,
                            room: room,
                            participants: participants,
                            screens: screens,
                            onScreenSelected: (identity) => setState(
                              () => _selectedScreenIdentity = identity,
                            ),
                          )
                  : _VoicePrejoinCard(state: state, channel: channel),
            ),
          ],
        );
      },
    );
  }
}

String _participantName(RemoteParticipant participant) =>
    participant.name.trim().isNotEmpty
    ? participant.name
    : participant.identity;

bool _participantMuted(RemoteParticipant participant) {
  final publications = participant.audioTrackPublications;
  return publications.isEmpty || publications.every((item) => item.muted);
}

class _VoicePrejoinCard extends StatelessWidget {
  const _VoicePrejoinCard({required this.state, required this.channel});

  final AppState state;
  final GuildChannel channel;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: constraints.maxWidth < 600 ? 16 : 32,
        vertical: constraints.maxWidth < 600 ? 24 : 56,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.all(constraints.maxWidth < 600 ? 24 : 36),
            decoration: BoxDecoration(
              color: GcColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: GcColors.border),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 32,
                  offset: Offset(0, 16),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    color: Color(0x265C5FE8),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.headset_mic_outlined,
                    size: 30,
                    color: GcColors.accentText,
                  ),
                ),
                const SizedBox(height: 22),
                const Text(
                  'ГОЛОСОВАЯ КОМНАТА',
                  style: TextStyle(
                    color: GcColors.accentText,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Вы не подключены',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 25, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Подключитесь, чтобы увидеть участников комнаты и статусы микрофонов.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: GcColors.textSecondary, height: 1.45),
                ),
                if (state.error != null) ...[
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF422830),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      state.error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: GcColors.danger,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
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
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            state.transferRequired
                                ? Icons.move_up_outlined
                                : Icons.login,
                          ),
                    label: Text(
                      channel.admissionClosed
                          ? 'Вход временно закрыт'
                          : state.voicePhase == VoicePhase.joining
                          ? 'Подключение…'
                          : state.transferRequired
                          ? 'Перенести подключение сюда'
                          : 'Подключиться',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _VoiceParticipantRoom extends StatelessWidget {
  const _VoiceParticipantRoom({
    required this.state,
    required this.room,
    required this.participants,
    required this.screens,
    required this.onScreenSelected,
  });

  final AppState state;
  final Room? room;
  final List<RemoteParticipant> participants;
  final List<RemoteParticipant> screens;
  final ValueChanged<String> onScreenSelected;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      padding: EdgeInsets.all(constraints.maxWidth < 600 ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Все в сборе',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${participants.length + 1} ${_peopleWord(participants.length + 1)} в комнате'
                      '${screens.isEmpty ? '' : ' · демонстраций: ${screens.length}'}',
                      style: const TextStyle(color: GcColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: const Color(0x2258D5A2),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _StatusDot(),
                    SizedBox(width: 7),
                    Text(
                      'Подключено',
                      style: TextStyle(
                        color: GcColors.success,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (state.error != null) ...[
            const SizedBox(height: 18),
            _ErrorBanner(message: state.error!),
          ],
          const SizedBox(height: 24),
          GridView.count(
            crossAxisCount: constraints.maxWidth < 460
                ? 1
                : constraints.maxWidth < 760
                ? 2
                : constraints.maxWidth < 1080
                ? 3
                : 4,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: constraints.maxWidth < 460 ? 2.25 : 1.45,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _VoiceParticipantCard(
                name: state.profile?.displayName.trim().isNotEmpty == true
                    ? state.profile!.displayName
                    : 'Вы',
                muted: state.microphoneMuted,
                speaking: room?.localParticipant?.isSpeaking ?? false,
                isLocal: true,
              ),
              for (final participant in participants)
                _VoiceParticipantCard(
                  name: _participantName(participant),
                  muted: _participantMuted(participant),
                  speaking: participant.isSpeaking,
                  hasScreen: screens.contains(participant),
                  onScreenTap: screens.contains(participant)
                      ? () => onScreenSelected(participant.identity)
                      : null,
                ),
            ],
          ),
        ],
      ),
    ),
  );
}

String _peopleWord(int value) {
  final mod100 = value % 100;
  final mod10 = value % 10;
  if (mod100 >= 11 && mod100 <= 14) return 'участников';
  if (mod10 == 1) return 'участник';
  if (mod10 >= 2 && mod10 <= 4) return 'участника';
  return 'участников';
}

class _VoiceScreenViewer extends StatelessWidget {
  const _VoiceScreenViewer({
    required this.track,
    required this.publisherName,
    required this.screens,
    required this.selectedIdentity,
    required this.localName,
    required this.localMuted,
    required this.localSpeaking,
    required this.participants,
    required this.onClose,
    required this.onScreenSelected,
  });

  final VideoTrack track;
  final String publisherName;
  final List<RemoteParticipant> screens;
  final String? selectedIdentity;
  final String localName;
  final bool localMuted;
  final bool localSpeaking;
  final List<RemoteParticipant> participants;
  final VoidCallback onClose;
  final ValueChanged<String> onScreenSelected;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(
        child: Container(
          color: const Color(0xFF080A0E),
          child: Stack(
            children: [
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 82),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: ColoredBox(
                      color: Colors.black,
                      child: VideoTrackRenderer(
                        track,
                        renderMode: VideoRenderMode.auto,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 28,
                top: 28,
                child: _ViewerLabel(name: publisherName),
              ),
              Positioned(
                right: 28,
                top: 28,
                child: IconButton.filledTonal(
                  tooltip: 'Вернуться к участникам',
                  onPressed: onClose,
                  icon: const Icon(Icons.close_fullscreen_outlined),
                ),
              ),
              if (screens.length > 1)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 14,
                  child: SizedBox(
                    height: 54,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: screens.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final participant = screens[index];
                        final selected =
                            participant.identity == selectedIdentity;
                        return OutlinedButton.icon(
                          onPressed: () =>
                              onScreenSelected(participant.identity),
                          icon: const Icon(Icons.monitor_outlined, size: 17),
                          label: Text(_participantName(participant)),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: selected
                                ? const Color(0x335C5FE8)
                                : GcColors.surface,
                            side: BorderSide(
                              color: selected
                                  ? GcColors.accentText
                                  : GcColors.border,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      _VoiceParticipantStrip(
        localName: localName,
        localMuted: localMuted,
        localSpeaking: localSpeaking,
        participants: participants,
      ),
    ],
  );
}

class _ViewerLabel extends StatelessWidget {
  const _ViewerLabel({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xD9141922),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0x446D7C94)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.monitor_outlined, size: 17),
        const SizedBox(width: 8),
        Text(
          'Экран $name',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );
}

class _VoiceParticipantStrip extends StatelessWidget {
  const _VoiceParticipantStrip({
    required this.localName,
    required this.localMuted,
    required this.localSpeaking,
    required this.participants,
  });

  final String localName;
  final bool localMuted;
  final bool localSpeaking;
  final List<RemoteParticipant> participants;

  @override
  Widget build(BuildContext context) => Container(
    height: 92,
    padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
    decoration: const BoxDecoration(
      color: GcColors.sidebar,
      border: Border(top: BorderSide(color: GcColors.border)),
    ),
    child: Row(
      children: [
        SizedBox(
          width: 110,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Участники',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 3),
              Text(
                '${participants.length + 1} в комнате',
                style: const TextStyle(color: GcColors.muted, fontSize: 11),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _VoiceStripPerson(
                name: localName,
                muted: localMuted,
                speaking: localSpeaking,
              ),
              for (final participant in participants)
                _VoiceStripPerson(
                  name: _participantName(participant),
                  muted: _participantMuted(participant),
                  speaking: participant.isSpeaking,
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _VoiceStripPerson extends StatelessWidget {
  const _VoiceStripPerson({
    required this.name,
    required this.muted,
    required this.speaking,
  });

  final String name;
  final bool muted;
  final bool speaking;

  @override
  Widget build(BuildContext context) => Container(
    width: 148,
    margin: const EdgeInsets.only(right: 8),
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(
      color: GcColors.surface,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: speaking ? GcColors.success : GcColors.border),
    ),
    child: Row(
      children: [
        _VoiceAvatar(name: name, size: 30, speaking: speaking),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
        Icon(
          muted ? Icons.mic_off : Icons.mic,
          size: 15,
          color: muted ? GcColors.danger : GcColors.muted,
        ),
      ],
    ),
  );
}

class _VoiceParticipantCard extends StatelessWidget {
  const _VoiceParticipantCard({
    required this.name,
    required this.muted,
    required this.speaking,
    this.hasScreen = false,
    this.isLocal = false,
    this.onScreenTap,
  });
  final String name;
  final bool muted;
  final bool speaking;
  final bool hasScreen;
  final bool isLocal;
  final VoidCallback? onScreenTap;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: GcColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: speaking ? GcColors.success : GcColors.border,
        width: speaking ? 2 : 1,
      ),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _VoiceAvatar(name: name, size: 62, speaking: speaking),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                isLocal ? '$name (вы)' : name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 7),
            Icon(
              muted ? Icons.mic_off : Icons.mic,
              size: 16,
              color: muted ? GcColors.danger : GcColors.textSecondary,
            ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          speaking
              ? 'Говорит'
              : muted
              ? 'Микрофон выключен'
              : 'Микрофон включён',
          style: TextStyle(
            color: speaking ? GcColors.success : GcColors.muted,
            fontSize: 12,
          ),
        ),
        if (hasScreen)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: OutlinedButton.icon(
              onPressed: onScreenTap,
              icon: const Icon(Icons.monitor_outlined, size: 16),
              label: const Text('Смотреть'),
              style: OutlinedButton.styleFrom(
                foregroundColor: GcColors.accentText,
                minimumSize: const Size(0, 34),
              ),
            ),
          ),
      ],
    ),
  );
}

class _VoiceAvatar extends StatelessWidget {
  const _VoiceAvatar({
    required this.name,
    required this.size,
    required this.speaking,
  });

  final String name;
  final double size;
  final bool speaking;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: const Color(0xFF365ACA),
      border: Border.all(
        color: speaking ? GcColors.success : const Color(0x44365ACA),
        width: speaking ? 3 : 1,
      ),
      boxShadow: speaking
          ? const [BoxShadow(color: Color(0x5558D5A2), blurRadius: 14)]
          : null,
    ),
    alignment: Alignment.center,
    child: Text(
      name.characters.first.toUpperCase(),
      style: TextStyle(
        fontSize: size * .36,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
    ),
  );
}

class _StatusDot extends StatelessWidget {
  const _StatusDot();

  @override
  Widget build(BuildContext context) => Container(
    width: 7,
    height: 7,
    decoration: const BoxDecoration(
      color: GcColors.success,
      shape: BoxShape.circle,
      boxShadow: [BoxShadow(color: Color(0x8858D5A2), blurRadius: 7)],
    ),
  );
}

class _VoiceDock extends StatelessWidget {
  const _VoiceDock({required this.state});
  final AppState state;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
    decoration: const BoxDecoration(
      color: GcColors.surface,
      border: Border(top: BorderSide(color: GcColors.border)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const _StatusDot(),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'В голосовом канале',
                    style: TextStyle(
                      color: GcColors.success,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    state.voiceChannel!.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: GcColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 11),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _VoiceDockButton(
              tooltip: state.microphoneMuted
                  ? 'Включить микрофон'
                  : 'Выключить микрофон',
              icon: state.microphoneMuted ? Icons.mic_off : Icons.mic,
              danger: state.microphoneMuted,
              onTap: state.toggleMicrophone,
            ),
            _VoiceDockButton(
              tooltip: state.deafened ? 'Включить звук' : 'Заглушить звук',
              icon: state.deafened ? Icons.headset_off : Icons.headphones,
              danger: state.deafened,
              onTap: state.toggleDeafen,
            ),
            _VoiceDockButton(
              tooltip: 'Отключиться',
              icon: Icons.call_end,
              danger: true,
              onTap: state.leaveVoice,
            ),
          ],
        ),
      ],
    ),
  );
}

class _VoiceDockButton extends StatelessWidget {
  const _VoiceDockButton({
    required this.icon,
    required this.tooltip,
    required this.danger,
    required this.onTap,
  });
  final IconData icon;
  final String tooltip;
  final bool danger;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Material(
      color: danger ? const Color(0x33422830) : GcColors.raised,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox.square(
          dimension: 42,
          child: Icon(
            icon,
            size: 19,
            color: danger ? GcColors.danger : GcColors.textSecondary,
          ),
        ),
      ),
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
          Expanded(
            child: InkWell(
              onTap: () => state.toggleWorkspacePanel(WorkspacePanel.profile),
              borderRadius: BorderRadius.circular(6),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: const Color(0xFF365ACA),
                    child: Text(
                      (state.profile?.displayName ?? 'В').characters.first
                          .toUpperCase(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          state.profile?.displayName ?? 'Профиль',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          state.user!.isAdmin ? 'Администратор' : 'Участник',
                          style: const TextStyle(
                            color: GcColors.muted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Настройки аккаунта',
            onSelected: (value) {
              if (value == 'logout') state.logout();
              if (value == 'profile') {
                state.toggleWorkspacePanel(WorkspacePanel.profile);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person_outline, size: 18),
                    SizedBox(width: 10),
                    Text('Профиль'),
                  ],
                ),
              ),
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
          const SizedBox(height: 14),
          Expanded(
            child: RefreshIndicator(
              onRefresh: state.refreshMembers,
              child: ListView.builder(
                itemCount: state.members.length,
                itemBuilder: (context, index) {
                  final member = state.members[index];
                  final presence = switch (member.presence) {
                    MemberPresence.online => ('В сети', GcColors.success),
                    MemberPresence.offline => ('Не в сети', GcColors.muted),
                    MemberPresence.unknown => (
                      'Статус неизвестен',
                      GcColors.warning,
                    ),
                  };
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    onTap: () => _showMemberDialog(context, state, member),
                    leading: Stack(
                      children: [
                        CircleAvatar(
                          child: Text(
                            member.displayName.characters.first.toUpperCase(),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 11,
                            height: 11,
                            decoration: BoxDecoration(
                              color: presence.$2,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: GcColors.sidebar,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    title: Text(
                      member.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      presence.$1,
                      style: const TextStyle(
                        color: GcColors.muted,
                        fontSize: 11,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

Future<void> _showMemberDialog(
  BuildContext context,
  AppState state,
  GuildMember member,
) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Row(
        children: [
          CircleAvatar(
            radius: 28,
            child: Text(member.displayName.characters.first.toUpperCase()),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(member.displayName),
                Text(
                  member.login,
                  style: const TextStyle(color: GcColors.muted, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
      content: Text(
        member.role == 'ADMINISTRATOR' ? 'Администратор' : 'Участник',
      ),
      actions: [
        if (member.id != state.user?.accountId)
          FilledButton.icon(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await state.createDirectConversation(
                DirectCandidate(id: member.id, displayName: member.displayName),
              );
            },
            icon: const Icon(Icons.chat_bubble_outline),
            label: const Text('Написать'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Закрыть'),
        ),
      ],
    ),
  );
}

Future<String?> _editMessageDialog(
  BuildContext context,
  String initialValue,
) async {
  final controller = TextEditingController(text: initialValue);
  final value = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Изменить сообщение'),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLength: 8000,
        minLines: 2,
        maxLines: 8,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, controller.text),
          child: const Text('Сохранить'),
        ),
      ],
    ),
  );
  controller.dispose();
  return value;
}

Future<bool> _confirmDelete(BuildContext context) async =>
    await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Удалить сообщение?'),
        content: const Text(
          'Текст будет заменён отметкой об удалении. Отменить это действие нельзя.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: GcColors.danger),
            child: const Text('Удалить'),
          ),
        ],
      ),
    ) ??
    false;

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
