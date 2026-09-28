import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:livekit_client/livekit_client.dart' hide ChatMessage;
import 'package:window_manager/window_manager.dart';

import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import '../services/message_presentation.dart';
import '../services/api_client.dart';
import '../services/voice_avatar_palette.dart';
import '../services/voice_participant_presentation.dart';
import '../widgets/authenticated_avatar.dart';
import '../widgets/message_attachment_composer.dart';
import '../widgets/message_attachment_list.dart';
import '../widgets/screen_share_setup_dialog.dart';
import '../widgets/formatted_message_body.dart';
import '../widgets/voice_connection_badge.dart';
import '../widgets/voice_microphone_unavailable_notice.dart';
import 'profile_screen.dart';
import 'admin_screen.dart';
import 'voice_screen_ended.dart';
import 'voice_screen_selection_rail.dart';
import 'voice_viewer_layout.dart';
import 'screen_receiver_diagnostics.dart';
import 'screen_fullscreen_overlay.dart';

class WorkspaceScreen extends StatefulWidget {
  const WorkspaceScreen({super.key, required this.state});
  final AppState state;

  @override
  State<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends State<WorkspaceScreen>
    with WidgetsBindingObserver, WindowListener {
  bool _showMobileSidebar = false;
  bool _showMembersDrawer = false;
  bool _capturingPttKey = false;
  FocusNode? _drawerReturnFocus;
  final _searchTriggerFocus = FocusNode(debugLabel: 'workspace-search-trigger');
  WorkspacePanel? _lastWorkspacePanel;

  @override
  void initState() {
    super.initState();
    _lastWorkspacePanel = widget.state.workspacePanel;
    widget.state.addListener(_workspaceChanged);
    HardwareKeyboard.instance.addHandler(_handleHardwareKey);
    WidgetsBinding.instance.addObserver(this);
    if (defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows) {
      windowManager.addListener(this);
    }
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleHardwareKey);
    WidgetsBinding.instance.removeObserver(this);
    if (defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows) {
      windowManager.removeListener(this);
    }
    unawaited(widget.state.setPushToTalkPressed(false));
    widget.state.removeListener(_workspaceChanged);
    _searchTriggerFocus.dispose();
    super.dispose();
  }

  void _workspaceChanged() {
    final previous = _lastWorkspacePanel;
    final current = widget.state.workspacePanel;
    _lastWorkspacePanel = current;
    if ((previous == WorkspacePanel.search ||
            previous == WorkspacePanel.searchContext) &&
        current == WorkspacePanel.none) {
      final compact =
          MediaQuery.sizeOf(context).width < GcLayout.mobileBreakpoint;
      if (compact) {
        setState(() => _showMobileSidebar = true);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _searchTriggerFocus.canRequestFocus) {
          _searchTriggerFocus.requestFocus();
        }
      });
    }
  }

  bool _handleHardwareKey(KeyEvent event) {
    if (_capturingPttKey && event is KeyDownEvent) {
      setState(() => _capturingPttKey = false);
      if (event.logicalKey == LogicalKeyboardKey.tab ||
          event.logicalKey == LogicalKeyboardKey.escape) {
        return true;
      }
      final keyLabel = event.logicalKey.keyLabel.trim().isEmpty
          ? event.logicalKey.debugName ?? 'Клавиша'
          : event.logicalKey.keyLabel;
      unawaited(
        widget.state.setPushToTalkKey(event.logicalKey.keyId, keyLabel),
      );
      return true;
    }
    final isPttKey = widget.state.pushToTalkKeyId == event.logicalKey.keyId;
    if (event is KeyUpEvent && isPttKey) {
      unawaited(widget.state.setPushToTalkPressed(false));
      return true;
    }
    if (event is KeyDownEvent &&
        isPttKey &&
        widget.state.audioActivationMode == AudioActivationMode.ptt) {
      final focusContext = FocusManager.instance.primaryFocus?.context;
      if (focusContext != null &&
          (focusContext.widget is EditableText ||
              focusContext.widget is ButtonStyleButton ||
              focusContext.findAncestorWidgetOfExactType<EditableText>() !=
                  null ||
              focusContext
                      .findAncestorWidgetOfExactType<
                        DropdownButton<String>
                      >() !=
                  null ||
              focusContext
                      .findAncestorWidgetOfExactType<
                        FormField<AudioActivationMode>
                      >() !=
                  null ||
              focusContext.findAncestorWidgetOfExactType<SwitchListTile>() !=
                  null ||
              focusContext.findAncestorWidgetOfExactType<Dialog>() != null)) {
        return false;
      }
      unawaited(widget.state.setPushToTalkPressed(true));
      return true;
    }
    if (event is! KeyDownEvent) return false;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      return _handleEscape();
    }
    if (event.logicalKey != LogicalKeyboardKey.keyK ||
        (!HardwareKeyboard.instance.isControlPressed &&
            !HardwareKeyboard.instance.isMetaPressed)) {
      return false;
    }
    return _handleSearchShortcut();
  }

  void _toggleSearch() {
    if (widget.state.workspacePanel == WorkspacePanel.search ||
        widget.state.workspacePanel == WorkspacePanel.searchContext) {
      widget.state.closeSearchPanel();
    } else {
      widget.state.openSearchPanel();
      _closeDrawers();
    }
  }

  bool _handleSearchShortcut() {
    final focusContext = FocusManager.instance.primaryFocus?.context;
    if (focusContext != null &&
        (focusContext.widget is EditableText ||
            focusContext.findAncestorWidgetOfExactType<EditableText>() !=
                null)) {
      return false;
    }
    _toggleSearch();
    return true;
  }

  void _closeDrawers() {
    if (!_showMobileSidebar && !_showMembersDrawer) return;
    final returnFocus = _drawerReturnFocus;
    final restoreFocus = widget.state.workspacePanel == WorkspacePanel.none;
    _drawerReturnFocus = null;
    setState(() {
      _showMobileSidebar = false;
      _showMembersDrawer = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !restoreFocus ||
          returnFocus?.context == null ||
          !returnFocus!.canRequestFocus) {
        return;
      }
      returnFocus.requestFocus();
    });
  }

  void _closeScrim() {
    _closeDrawers();
    if (widget.state.workspacePanel == WorkspacePanel.search) {
      widget.state.closeSearchPanel();
    }
  }

  bool _handleEscape() {
    if (_showMobileSidebar || _showMembersDrawer) {
      _closeDrawers();
      return true;
    } else if (widget.state.workspacePanel == WorkspacePanel.search ||
        widget.state.workspacePanel == WorkspacePanel.searchContext) {
      widget.state.closeSearchPanel();
      return true;
    }
    return false;
  }

  void _toggleNavigation() {
    if (!_showMobileSidebar && !_showMembersDrawer) {
      _drawerReturnFocus = FocusManager.instance.primaryFocus;
    }
    setState(() {
      _showMobileSidebar = !_showMobileSidebar;
      _showMembersDrawer = false;
    });
  }

  void _toggleMembers() {
    if (!_showMobileSidebar && !_showMembersDrawer) {
      _drawerReturnFocus = FocusManager.instance.primaryFocus;
    }
    setState(() {
      _showMembersDrawer = !_showMembersDrawer;
      _showMobileSidebar = false;
    });
  }

  void _beginPttKeyCapture() => setState(() => _capturingPttKey = true);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    widget.state.setNotificationAppForeground(
      state == AppLifecycleState.resumed,
    );
    if (state != AppLifecycleState.resumed) {
      unawaited(widget.state.setPushToTalkPressed(false));
    } else {
      unawaited(widget.state.refreshNotificationStatus());
    }
  }

  @override
  void onWindowFocus() {
    widget.state.setNotificationAppForeground(true);
    unawaited(widget.state.refreshNotificationStatus());
  }

  @override
  void onWindowBlur() {
    widget.state.setNotificationAppForeground(false);
    unawaited(widget.state.setPushToTalkPressed(false));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < GcLayout.mobileBreakpoint;
          final medium = constraints.maxWidth >= GcLayout.mediumBreakpoint;
          final wide = constraints.maxWidth >= GcLayout.wideBreakpoint;
          final voiceStageWide =
              wide && widget.state.selectedChannel?.kind == ChannelKind.voice;
          final searchPanelActive =
              widget.state.workspacePanel == WorkspacePanel.search;
          final searchPanelModal =
              searchPanelActive && (!medium || voiceStageWide);
          final modalOverlayActive = _showMembersDrawer || searchPanelModal;
          final showPermanentMembers =
              medium &&
              widget.state.workspacePanel == WorkspacePanel.none &&
              widget.state.selectedDirectMessage == null &&
              !voiceStageWide;
          final showMemberToggle =
              !showPermanentMembers &&
              widget.state.workspacePanel == WorkspacePanel.none &&
              widget.state.selectedDirectMessage == null;
          final content = compact
              ? Stack(
                  children: [
                    Positioned.fill(
                      child: ExcludeFocus(
                        excluding:
                            _showMobileSidebar ||
                            _showMembersDrawer ||
                            searchPanelModal,
                        child: _MainSurface(
                          state: widget.state,
                          onToggleNavigation: _toggleNavigation,
                          onOpenMembers: showMemberToggle
                              ? _toggleMembers
                              : null,
                          onCapturePttKey: _beginPttKeyCapture,
                          capturingPttKey: _capturingPttKey,
                        ),
                      ),
                    ),
                    if (_showMobileSidebar ||
                        _showMembersDrawer ||
                        searchPanelModal)
                      Positioned.fill(child: _DrawerScrim(onTap: _closeScrim)),
                    if (_showMobileSidebar)
                      Positioned(
                        top: 0,
                        bottom: 0,
                        left: 0,
                        width: (constraints.maxWidth - 40)
                            .clamp(0.0, 320.0)
                            .toDouble(),
                        child: _DrawerSurface(
                          child: _Sidebar(
                            state: widget.state,
                            onChannelSelected: _closeDrawers,
                            onClose: _closeDrawers,
                            onSearch: _toggleSearch,
                            searchFocusNode: _searchTriggerFocus,
                          ),
                        ),
                      ),
                    if (_showMembersDrawer)
                      Positioned(
                        top: 0,
                        bottom: 0,
                        right: 0,
                        width: (constraints.maxWidth - 40)
                            .clamp(0.0, 320.0)
                            .toDouble(),
                        child: _DrawerSurface(
                          child: _MembersPanel(
                            state: widget.state,
                            onClose: _closeDrawers,
                          ),
                        ),
                      ),
                    if (searchPanelModal)
                      Positioned(
                        top: 0,
                        bottom: 0,
                        right: 0,
                        width: (constraints.maxWidth - 40)
                            .clamp(0.0, 320.0)
                            .toDouble(),
                        child: _DrawerSurface(
                          debugLabel: 'workspace-search',
                          child: _WorkspaceSearchPanel(state: widget.state),
                        ),
                      ),
                  ],
                )
              : Stack(
                  children: [
                    ExcludeFocus(
                      excluding: modalOverlayActive,
                      child: Row(
                        children: [
                          SizedBox(
                            width: wide
                                ? GcLayout.navWide
                                : medium
                                ? GcLayout.navMedium
                                : GcLayout.navSmall,
                            child: _Sidebar(
                              state: widget.state,
                              onSearch: _toggleSearch,
                              searchFocusNode: _searchTriggerFocus,
                            ),
                          ),
                          const VerticalDivider(width: 1),
                          Expanded(
                            child: _MainSurface(
                              state: widget.state,
                              onOpenMembers: showMemberToggle
                                  ? _toggleMembers
                                  : null,
                              onCapturePttKey: _beginPttKeyCapture,
                              capturingPttKey: _capturingPttKey,
                            ),
                          ),
                          if (showPermanentMembers) ...[
                            const VerticalDivider(width: 1),
                            SizedBox(
                              width: wide
                                  ? GcLayout.asideWide
                                  : GcLayout.asideMedium,
                              child: _MembersPanel(state: widget.state),
                            ),
                          ],
                          if (searchPanelActive && !searchPanelModal) ...[
                            const VerticalDivider(width: 1),
                            SizedBox(
                              width: wide ? 400 : 360,
                              child: _WorkspaceSearchPanel(state: widget.state),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (_showMembersDrawer || searchPanelModal)
                      Positioned.fill(child: _DrawerScrim(onTap: _closeScrim)),
                    if (_showMembersDrawer)
                      Positioned(
                        top: 0,
                        bottom: 0,
                        right: 0,
                        width: (constraints.maxWidth - 32)
                            .clamp(0.0, 320.0)
                            .toDouble(),
                        child: _DrawerSurface(
                          child: _MembersPanel(
                            state: widget.state,
                            onClose: _closeDrawers,
                          ),
                        ),
                      ),
                    if (searchPanelModal)
                      Positioned(
                        top: 0,
                        bottom: 0,
                        right: 0,
                        width: (constraints.maxWidth - 32)
                            .clamp(0.0, 320.0)
                            .toDouble(),
                        child: _DrawerSurface(
                          debugLabel: 'workspace-search',
                          child: _WorkspaceSearchPanel(state: widget.state),
                        ),
                      ),
                  ],
                );
          final flushShell = constraints.maxWidth >= GcLayout.wideBreakpoint;
          return Padding(
            padding: compact || flushShell
                ? EdgeInsets.zero
                : const EdgeInsets.all(GcLayout.frameInset),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(
                compact || flushShell ? 0 : GcLayout.shellRadius,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: compact || flushShell
                      ? null
                      : Border.all(color: GcColors.border),
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

class _DrawerScrim extends StatelessWidget {
  const _DrawerScrim({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Закрыть панель',
    child: GestureDetector(
      onTap: onTap,
      child: const ColoredBox(color: Color(0xA8000000)),
    ),
  );
}

class _DrawerSurface extends StatefulWidget {
  const _DrawerSurface({
    required this.child,
    this.debugLabel = 'workspace-drawer',
  });
  final Widget child;
  final String debugLabel;

  @override
  State<_DrawerSurface> createState() => _DrawerSurfaceState();
}

class _DrawerSurfaceState extends State<_DrawerSurface> {
  late final FocusScopeNode _focusScope = FocusScopeNode(
    debugLabel: widget.debugLabel,
    traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
  );

  @override
  void dispose() {
    _focusScope.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FocusScope(
    node: _focusScope,
    autofocus: true,
    child: Material(
      color: GcColors.sidebar,
      elevation: 20,
      shadowColor: const Color(0x40000000),
      child: widget.child,
    ),
  );
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.state,
    this.onChannelSelected,
    this.onClose,
    this.onSearch,
    this.searchFocusNode,
  });
  final AppState state;
  final VoidCallback? onChannelSelected;
  final VoidCallback? onClose;
  final VoidCallback? onSearch;
  final FocusNode? searchFocusNode;
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
                  tooltip: 'Поиск сообщений',
                  focusNode: searchFocusNode,
                  onPressed: onSearch ?? state.openSearchPanel,
                  icon: const Icon(Icons.search),
                ),
                if (onClose != null)
                  IconButton(
                    tooltip: 'Закрыть навигацию',
                    onPressed: onClose,
                    icon: const Icon(Icons.close),
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
        _UserFooter(state: state, onNavigate: onClose),
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
        if (category.channels.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Text(
              'Нет каналов',
              style: TextStyle(color: GcColors.muted, fontSize: 12),
            ),
          ),
        for (final channel in category.channels) ...[
          Builder(
            builder: (context) {
              final room = state.voiceChannel?.id == channel.id
                  ? state.room
                  : null;
              final localParticipant = room?.localParticipant;
              final roster = state.voiceRosters
                  ?.where((item) => item.channelId == channel.id)
                  .firstOrNull;
              final memberCount = localParticipant == null
                  ? roster?.participants.length
                  : room!.remoteParticipants.length + 1;
              return Column(
                children: [
                  _ChannelRow(
                    channel: channel,
                    selected: state.selectedChannel?.id == channel.id,
                    voiceConnected: state.voiceChannel?.id == channel.id,
                    voiceParticipantCount: memberCount,
                    onTap: () {
                      state.selectChannel(channel);
                      onChannelSelected?.call();
                    },
                  ),
                  if (localParticipant != null)
                    _VoiceNavigationMembers(
                      state: state,
                      localParticipant: localParticipant,
                      remoteParticipants: room!.remoteParticipants.values,
                    )
                  else if (channel.kind == ChannelKind.voice &&
                      roster != null &&
                      roster.participants.isNotEmpty)
                    _VoiceRosterNavigationMembers(roster: roster),
                ],
              );
            },
          ),
        ],
      ],
    ),
  );
}

class _ChannelRow extends StatelessWidget {
  const _ChannelRow({
    required this.channel,
    required this.selected,
    required this.voiceConnected,
    this.voiceParticipantCount,
    required this.onTap,
  });
  final GuildChannel channel;
  final bool selected;
  final bool voiceConnected;
  final int? voiceParticipantCount;
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
              if (channel.kind == ChannelKind.text && channel.unreadCount > 0)
                _ChannelStateBadge(
                  label: '${channel.unreadCount}',
                  semanticLabel:
                      'Непрочитанных сообщений: ${channel.unreadCount}',
                ),
              if (channel.kind == ChannelKind.text && channel.mentionCount > 0)
                _ChannelStateBadge(
                  label: '@${channel.mentionCount}',
                  semanticLabel: 'Упоминаний: ${channel.mentionCount}',
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
              if (voiceParticipantCount != null)
                Padding(
                  padding: const EdgeInsets.only(right: 9),
                  child: Tooltip(
                    message:
                        'Участников в голосовом канале: $voiceParticipantCount',
                    child: Semantics(
                      label:
                          'Участников в голосовом канале: $voiceParticipantCount',
                      child: Text(
                        '$voiceParticipantCount',
                        style: const TextStyle(
                          color: GcColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _VoiceNavigationMembers extends StatelessWidget {
  const _VoiceNavigationMembers({
    required this.state,
    required this.localParticipant,
    required this.remoteParticipants,
  });

  final AppState state;
  final LocalParticipant localParticipant;
  final Iterable<RemoteParticipant> remoteParticipants;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(40, 4, 8, 8),
    child: Column(
      children: [
        _VoiceNavigationMemberRow(
          state: state,
          name: state.profile?.displayName.trim().isNotEmpty == true
              ? '${state.profile!.displayName} · вы'
              : 'Вы',
          accountId: state.user?.accountId,
          muted: state.microphoneMuted,
          microphoneUnavailable: state.microphoneUnavailable,
          deafened: state.deafened,
          speaking: localParticipant.isSpeaking,
          screenSharing: state.screenSharePhase == ScreenSharePhase.sharing,
        ),
        for (final participant in remoteParticipants) ...[
          const SizedBox(height: 4),
          _VoiceNavigationMemberRow(
            state: state,
            name: _participantName(participant),
            accountId: _voiceParticipantAccountId(participant),
            muted: _participantMuted(participant),
            speaking: participant.isSpeaking && !_participantMuted(participant),
            screenSharing: participant.videoTrackPublications.any(
              (publication) =>
                  publication.source == TrackSource.screenShareVideo &&
                  publication.track != null,
            ),
          ),
        ],
      ],
    ),
  );
}

class _VoiceRosterNavigationMembers extends StatelessWidget {
  const _VoiceRosterNavigationMembers({required this.roster});

  final VoiceRoomRoster roster;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(40, 4, 8, 8),
    child: Column(
      children: [
        for (var index = 0; index < roster.participants.length; index++) ...[
          if (index > 0) const SizedBox(height: 4),
          _VoiceRosterMemberRow(
            participant: roster.participants[index],
            compact: true,
          ),
        ],
      ],
    ),
  );
}

class _VoiceRosterMemberRow extends StatelessWidget {
  const _VoiceRosterMemberRow({
    required this.participant,
    this.compact = false,
  });

  final VoiceRosterMember participant;
  final bool compact;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 24,
    child: Row(
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: _voiceAvatarColor(participant.accountId),
          child: Text(
            _initial(participant.displayName),
            style: TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            participant.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: GcColors.textSecondary, fontSize: 12),
          ),
        ),
        if (participant.screenSharing)
          Tooltip(
            message: 'Показывает экран',
            child: Container(
              decoration: BoxDecoration(
                color: GcColors.selected,
                border: Border.all(color: GcColors.accent),
                borderRadius: BorderRadius.circular(GcRadii.sm),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.desktop_windows_outlined,
                    size: 16,
                    color: GcColors.accentText,
                  ),
                  if (!compact) ...[
                    const SizedBox(width: 4),
                    const Text(
                      'Идёт трансляция',
                      style: TextStyle(
                        color: GcColors.accentText,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    ),
  );
}

String _initial(String value) =>
    value.trim().isEmpty ? 'У' : value.trim().characters.first.toUpperCase();

class _VoiceNavigationMemberRow extends StatelessWidget {
  const _VoiceNavigationMemberRow({
    required this.state,
    required this.name,
    required this.accountId,
    required this.muted,
    required this.speaking,
    required this.screenSharing,
    this.microphoneUnavailable = false,
    this.deafened = false,
  });

  final AppState state;
  final String name;
  final String? accountId;
  final bool muted;
  final bool microphoneUnavailable;
  final bool deafened;
  final bool speaking;
  final bool screenSharing;

  @override
  Widget build(BuildContext context) {
    final presentation = VoiceParticipantPresentation.resolve(
      muted: muted,
      microphoneUnavailable: microphoneUnavailable,
      deafened: deafened,
      speaking: speaking,
    );
    final member = accountId == null
        ? null
        : state.members.where((item) => item.id == accountId).firstOrNull;
    return SizedBox(
      height: 24,
      child: Row(
        children: [
          AuthenticatedAvatar(
            state: state,
            name: name,
            avatarUrl: member?.avatarUrl,
            radius: 12,
            backgroundColor: _voiceAvatarColor(accountId ?? name),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: presentation.isSpeaking
                    ? GcColors.success
                    : GcColors.textSecondary,
                fontSize: 12,
                fontWeight: presentation.isSpeaking
                    ? FontWeight.w600
                    : FontWeight.w400,
              ),
            ),
          ),
          if (screenSharing)
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Tooltip(
                message: 'Показывает экран',
                child: Icon(
                  Icons.desktop_windows_outlined,
                  size: 16,
                  color: GcColors.accentText,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Tooltip(
              message: presentation.label,
              child: Icon(
                deafened
                    ? Icons.headset_off
                    : presentation.isSpeaking
                    ? Icons.graphic_eq
                    : muted || microphoneUnavailable
                    ? Icons.mic_off_outlined
                    : Icons.mic_none,
                size: 16,
                color: deafened
                    ? GcColors.danger
                    : microphoneUnavailable
                    ? GcColors.warning
                    : muted
                    ? GcColors.muted
                    : GcColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String? _voiceParticipantAccountId(RemoteParticipant participant) {
  final metadata = participant.metadata;
  if (metadata == null || !metadata.startsWith('account:')) return null;
  final id = metadata.substring('account:'.length);
  return id.isEmpty ? null : id;
}

Color _voiceAvatarColor(String value) {
  const colors = [
    GcColors.avatarBlue,
    GcColors.avatarGreen,
    GcColors.avatarViolet,
    GcColors.avatarOrange,
    GcColors.avatarGray,
  ];
  return colors[voiceAvatarPaletteIndex(value)];
}

class _ChannelStateBadge extends StatelessWidget {
  const _ChannelStateBadge({required this.label, required this.semanticLabel});
  final String label;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) => Semantics(
    label: semanticLabel,
    child: ExcludeSemantics(
      child: Container(
        constraints: const BoxConstraints(minHeight: 20),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: GcColors.warningBackground,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: GcColors.warning,
            fontSize: 11,
            height: 1.2,
          ),
        ),
      ),
    ),
  );
}

class _MainSurface extends StatelessWidget {
  const _MainSurface({
    required this.state,
    this.onToggleNavigation,
    this.onOpenMembers,
    this.onCapturePttKey,
    this.capturingPttKey = false,
  });
  final AppState state;
  final VoidCallback? onToggleNavigation;
  final VoidCallback? onOpenMembers;
  final VoidCallback? onCapturePttKey;
  final bool capturingPttKey;
  @override
  Widget build(BuildContext context) {
    final compact =
        MediaQuery.sizeOf(context).width < GcLayout.mobileBreakpoint;
    void leaveWorkspacePanel() {
      state.toggleWorkspacePanel(WorkspacePanel.none);
    }

    if (state.workspacePanel == WorkspacePanel.searchContext) {
      return _SearchMessageContext(state: state);
    }
    if (state.workspacePanel == WorkspacePanel.profile) {
      return PopScope<Object?>(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) leaveWorkspacePanel();
        },
        child: Column(
          children: [
            _ProfilePanelToolbar(
              onToggleNavigation: onToggleNavigation,
              onBack: compact ? leaveWorkspacePanel : null,
            ),
            Expanded(child: ProfileScreen(state: state)),
          ],
        ),
      );
    }
    if (state.workspacePanel == WorkspacePanel.audio) {
      return _AudioSettingsScreen(
        state: state,
        onBack: leaveWorkspacePanel,
        onCapturePttKey: onCapturePttKey,
        capturingPttKey: capturingPttKey,
      );
    }
    if (state.workspacePanel == WorkspacePanel.admin &&
        state.user?.isAdmin == true) {
      return PopScope<Object?>(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) leaveWorkspacePanel();
        },
        child: AdminScreen(state: state),
      );
    }
    final direct = state.selectedDirectMessage;
    if (direct != null) {
      return ColoredBox(
        color: GcColors.content,
        child: _DirectConversation(
          state: state,
          conversation: direct,
          onToggleNavigation: onToggleNavigation,
          onOpenMembers: onOpenMembers,
        ),
      );
    }
    final channel = state.selectedChannel;
    if (channel == null) {
      return Column(
        children: [
          _Header(
            icon: Icons.forum_outlined,
            title: 'Моя гильдия',
            subtitle: 'Выберите канал',
            onToggleNavigation: onToggleNavigation,
            onOpenMembers: onOpenMembers,
          ),
          const Expanded(
            child: ColoredBox(
              color: GcColors.content,
              child: Center(
                child: Text(
                  'Выберите канал',
                  style: TextStyle(color: GcColors.muted),
                ),
              ),
            ),
          ),
        ],
      );
    }
    return ColoredBox(
      color: GcColors.content,
      child: channel.kind == ChannelKind.text
          ? _Conversation(
              state: state,
              channel: channel,
              onToggleNavigation: onToggleNavigation,
              onOpenMembers: onOpenMembers,
            )
          : _VoiceRoom(
              key: ValueKey('voice-room:${channel.id}'),
              state: state,
              channel: channel,
              onToggleNavigation: onToggleNavigation,
              onOpenMembers: onOpenMembers,
            ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onToggleNavigation,
    this.onOpenMembers,
    this.onBack,
    this.trailing,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onToggleNavigation;
  final VoidCallback? onOpenMembers;
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
            if (onBack != null)
              IconButton(
                tooltip: 'Назад',
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back),
              ),
            if (onToggleNavigation != null) ...[
              IconButton(
                tooltip: 'Открыть навигацию',
                onPressed: onToggleNavigation,
                icon: const Icon(Icons.menu),
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
            if (onOpenMembers != null)
              IconButton(
                tooltip: 'Открыть участников',
                onPressed: onOpenMembers,
                icon: const Icon(Icons.people_outline),
              ),
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
    this.onToggleNavigation,
    this.onOpenMembers,
  });
  final AppState state;
  final GuildChannel channel;
  final VoidCallback? onToggleNavigation;
  final VoidCallback? onOpenMembers;
  @override
  State<_Conversation> createState() => _ConversationState();
}

class _ConversationState extends State<_Conversation>
    with WidgetsBindingObserver {
  final _controller = TextEditingController();
  final _composerFocus = FocusNode();
  final _attachmentComposerKey = GlobalKey<MessageAttachmentComposerState>();
  final _scroll = ScrollController();
  final Map<String, GlobalKey> _messageKeys = {};
  final Set<String> _mentionUserIds = {};
  List<MessageAttachment> _attachments = const [];
  bool _attachmentsPending = false;
  ChatMessage? _replyTarget;
  bool _followLatest = true;
  bool _latestLayoutConfirmed = false;
  String? _observedChannelId;
  List<ChatMessage>? _observedMessages;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scroll.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant _Conversation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.channel.id != widget.channel.id) {
      _followLatest = true;
      _latestLayoutConfirmed = false;
      _replyTarget = null;
      _mentionUserIds.clear();
      _attachments = const [];
      _attachmentsPending = false;
      _observedChannelId = null;
      _observedMessages = null;
    }
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    _followLatest = _scroll.position.extentAfter <= 48;
    _scheduleVisibleRead(widget.state.messages);
  }

  void _scheduleVisibleRead(List<ChatMessage> renderedMessages) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          widget.state.loadingMessages ||
          widget.state.selectedChannel?.id != widget.channel.id ||
          !identical(widget.state.messages, renderedMessages) ||
          !_scroll.hasClients) {
        return;
      }
      if (_followLatest && _scroll.position.extentAfter > 1) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
        _scheduleVisibleRead(renderedMessages);
        return;
      }
      if (_followLatest && !_latestLayoutConfirmed) {
        _latestLayoutConfirmed = true;
        _scheduleVisibleRead(renderedMessages);
        return;
      }
      if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
        return;
      }
      final visibleMessages = <ChatMessage>[];
      for (final message in renderedMessages) {
        if (message.sendStatus != null) continue;
        final row = _messageKeys['${widget.channel.id}:${message.id}']
            ?.currentContext
            ?.findRenderObject();
        if (row is! RenderBox || !row.attached) continue;
        final candidateViewport = RenderAbstractViewport.maybeOf(row);
        if (candidateViewport is! RenderBox) continue;
        final viewportBox = candidateViewport as RenderBox;
        final rowRect = row.localToGlobal(Offset.zero) & row.size;
        final viewportRect =
            viewportBox.localToGlobal(Offset.zero) & viewportBox.size;
        if (rowRect.bottom > viewportRect.top &&
            rowRect.top < viewportRect.bottom &&
            rowRect.right > viewportRect.left &&
            rowRect.left < viewportRect.right) {
          visibleMessages.add(message);
        }
      }
      final newestVisible = visibleMessages.lastOrNull;
      if (newestVisible != null) {
        unawaited(
          widget.state.markTextChannelRead(widget.channel.id, newestVisible.id),
        );
      }
    });
  }

  Future<void> _pasteFromClipboard() async {
    await _attachmentComposerKey.currentState?.pasteFromClipboard();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _scheduleVisibleRead(widget.state.messages);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    _composerFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_attachmentsPending) return;
    final body = _controller.text;
    final replyId = _replyTarget?.id;
    final mentionIds = _mentionUserIds.toSet();
    final attachmentIds = _attachments.map((item) => item.id).toList();
    final sent = await widget.state.send(
      body,
      replyToId: replyId,
      mentionUserIds: _mentionUserIds.toList(),
      attachments: _attachments,
    );
    if (!sent ||
        !mounted ||
        widget.state.selectedChannel?.id != widget.channel.id) {
      return;
    }
    if (_controller.text != body ||
        _replyTarget?.id != replyId ||
        !setEquals(_mentionUserIds, mentionIds) ||
        !listEquals(
          _attachments.map((item) => item.id).toList(),
          attachmentIds,
        )) {
      return;
    }
    _controller.clear();
    setState(() {
      _replyTarget = null;
      _mentionUserIds.clear();
      _attachments = const [];
    });
    _followLatest = true;
    await Future<void>.delayed(const Duration(milliseconds: 80));
    if (mounted && _scroll.hasClients) {
      await _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _retry(ChatMessage message) async {
    final body = _controller.text;
    final replyId = _replyTarget?.id;
    final mentionIds = _mentionUserIds.toSet();
    final attachmentIds = _attachments.map((item) => item.id).toList();
    final sent = await widget.state.retryTextSend(message.clientMessageId!);
    if (!sent ||
        !mounted ||
        widget.state.selectedChannel?.id != widget.channel.id ||
        body.trim() != message.body ||
        _controller.text != body ||
        replyId != message.replyToId ||
        _replyTarget?.id != replyId ||
        !setEquals(mentionIds, message.mentionUserIds.toSet()) ||
        !setEquals(_mentionUserIds, mentionIds) ||
        !listEquals(
          attachmentIds,
          message.attachments.map((item) => item.id).toList(),
        ) ||
        !listEquals(
          _attachments.map((item) => item.id).toList(),
          attachmentIds,
        )) {
      return;
    }
    _controller.clear();
    setState(() {
      _replyTarget = null;
      _mentionUserIds.clear();
      _attachments = const [];
    });
  }

  void _replyTo(ChatMessage message) {
    setState(() => _replyTarget = message);
    _composerFocus.requestFocus();
  }

  Future<void> _loadOlder() async {
    if (!_scroll.hasClients) return;
    final oldOffset = _scroll.position.pixels;
    final oldExtent = _scroll.position.maxScrollExtent;
    if (!await widget.state.loadOlderMessages() || !mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final position = _scroll.position;
      final restored = oldOffset + position.maxScrollExtent - oldExtent;
      position.jumpTo(
        restored.clamp(position.minScrollExtent, position.maxScrollExtent),
      );
      _followLatest = false;
    });
  }

  void _jumpToReply(ChatMessage message) {
    final targetId = message.replyToId;
    if (targetId == null) return;
    final context =
        _messageKeys['${widget.channel.id}:$targetId']?.currentContext;
    if (context != null) {
      unawaited(
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 220),
          alignment: 0.25,
        ),
      );
    }
  }

  String? _replyPreview(ChatMessage message) {
    final replyToId = message.replyToId;
    if (replyToId == null) return null;
    final target = widget.state.messages
        .where((candidate) => candidate.id == replyToId)
        .firstOrNull;
    if (target == null) return 'Исходное сообщение недоступно';
    if (target.deleted) return 'Сообщение удалено';
    return '${_mentionDisplayName(widget.state, target.authorId)}: ${_messageSnippet(target.body)}';
  }

  @override
  Widget build(BuildContext context) {
    final renderedMessages = widget.state.messages;
    final timeline = messageTimeline(renderedMessages);
    if (_observedChannelId != widget.channel.id ||
        !identical(_observedMessages, renderedMessages)) {
      _observedChannelId = widget.channel.id;
      _observedMessages = renderedMessages;
      final renderedKeys = renderedMessages
          .map((message) => '${widget.channel.id}:${message.id}')
          .toSet();
      _messageKeys.removeWhere((key, _) => !renderedKeys.contains(key));
      _scheduleVisibleRead(renderedMessages);
    }
    return Column(
      children: [
        _Header(
          icon: Icons.tag_rounded,
          title: widget.channel.name,
          subtitle: 'Текстовый канал',
          onToggleNavigation: widget.onToggleNavigation,
          onOpenMembers: widget.onOpenMembers,
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
              : ListView.separated(
                  controller: _scroll,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 24,
                  ),
                  itemCount:
                      timeline.length +
                      (widget.state.nextMessageCursor == null ? 0 : 1),
                  separatorBuilder: (context, index) {
                    if (widget.state.nextMessageCursor != null && index == 0) {
                      return const SizedBox(height: 12);
                    }
                    final timelineIndex =
                        index -
                        (widget.state.nextMessageCursor == null ? 0 : 1);
                    final current = timeline[timelineIndex];
                    final next = timeline[timelineIndex + 1];
                    if (current.message == null) {
                      return const SizedBox(height: 12);
                    }
                    return SizedBox(
                      height: next.message != null && next.grouped ? 4 : 24,
                    );
                  },
                  itemBuilder: (context, index) {
                    if (widget.state.nextMessageCursor != null && index == 0) {
                      return Center(
                        child: TextButton.icon(
                          onPressed: widget.state.loadingOlderMessages
                              ? null
                              : _loadOlder,
                          icon: widget.state.loadingOlderMessages
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.history),
                          label: Text(
                            widget.state.loadingOlderMessages
                                ? 'Загружаем…'
                                : 'Загрузить предыдущие сообщения',
                          ),
                        ),
                      );
                    }
                    final timelineIndex =
                        index -
                        (widget.state.nextMessageCursor == null ? 0 : 1);
                    final entry = timeline[timelineIndex];
                    if (entry.message == null) {
                      return _HistoryDateDivider(label: entry.dateLabel!);
                    }
                    final message = entry.message!;
                    final key = '${widget.channel.id}:${message.id}';
                    return KeyedSubtree(
                      key: _messageKeys.putIfAbsent(
                        key,
                        () => GlobalKey(debugLabel: key),
                      ),
                      child: _MessageRow(
                        state: widget.state,
                        message: message,
                        grouped: entry.grouped,
                        replyPreview: _replyPreview(message),
                        onReply: _replyTo,
                        onJumpToReply: () => _jumpToReply(message),
                        onRetry: message.clientMessageId == null
                            ? null
                            : () => _retry(message),
                      ),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_replyTarget != null)
                _ReplyTargetBanner(
                  text:
                      'Ответ для ${_mentionDisplayName(widget.state, _replyTarget!.authorId)}',
                  onCancel: () => setState(() => _replyTarget = null),
                ),
              _MentionPicker(
                options: widget.state.members
                    .map((member) => (member.id, member.displayName))
                    .toList(growable: false),
                selfId: widget.state.user?.accountId ?? '',
                selectedIds: _mentionUserIds,
                onChanged: (ids) => setState(() {
                  _mentionUserIds
                    ..clear()
                    ..addAll(ids);
                }),
              ),
              MessageAttachmentComposer(
                key: _attachmentComposerKey,
                state: widget.state,
                channelId: widget.channel.id,
                textController: _controller,
                focusNode: _composerFocus,
                attachments: _attachments,
                onChanged: (attachments) => setState(() {
                  _attachments = attachments;
                }),
                onPending: (pending) => setState(() {
                  _attachmentsPending = pending;
                }),
                directMessageId: null,
              ),
              CallbackShortcuts(
                bindings: {
                  const SingleActivator(LogicalKeyboardKey.enter): _send,
                  const SingleActivator(LogicalKeyboardKey.keyV, control: true):
                      _pasteFromClipboard,
                  const SingleActivator(LogicalKeyboardKey.keyV, meta: true):
                      _pasteFromClipboard,
                  const SingleActivator(LogicalKeyboardKey.insert, shift: true):
                      _pasteFromClipboard,
                },
                child: TextField(
                  focusNode: _composerFocus,
                  controller: _controller,
                  contextMenuBuilder: (context, editableTextState) =>
                      _messageContextMenu(
                        context,
                        editableTextState,
                        _pasteFromClipboard,
                      ),
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
                      onPressed: widget.state.sending || _attachmentsPending
                          ? null
                          : _send,
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
            ],
          ),
        ),
      ],
    );
  }
}

Widget _messageContextMenu(
  BuildContext context,
  EditableTextState editableTextState,
  Future<void> Function() pasteFromClipboard,
) {
  final items =
      List<ContextMenuButtonItem>.of(editableTextState.contextMenuButtonItems)
        ..add(
          ContextMenuButtonItem(
            label: 'Вставить из буфера',
            onPressed: () {
              editableTextState.hideToolbar();
              unawaited(pasteFromClipboard());
            },
          ),
        );
  return AdaptiveTextSelectionToolbar.buttonItems(
    anchors: editableTextState.contextMenuAnchors,
    buttonItems: items,
  );
}

class _HistoryDateDivider extends StatelessWidget {
  const _HistoryDateDivider({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Row(
      children: [
        const Expanded(child: Divider(height: 1, color: GcColors.border)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: const TextStyle(color: GcColors.muted, fontSize: 12),
          ),
        ),
        const Expanded(child: Divider(height: 1, color: GcColors.border)),
      ],
    ),
  );
}

class _MessageRow extends StatelessWidget {
  const _MessageRow({
    required this.state,
    required this.message,
    this.grouped = false,
    this.replyPreview,
    this.onReply,
    this.onJumpToReply,
    this.onRetry,
  });
  final AppState state;
  final ChatMessage message;
  final bool grouped;
  final String? replyPreview;
  final ValueChanged<ChatMessage>? onReply;
  final VoidCallback? onJumpToReply;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) {
    final member = state.members
        .where((value) => value.id == message.authorId)
        .firstOrNull;
    final authorName = member?.displayName ?? message.authorId;
    final time =
        '${message.createdAt.hour.toString().padLeft(2, '0')}:${message.createdAt.minute.toString().padLeft(2, '0')}';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (grouped)
          const SizedBox(width: 40, height: 0)
        else
          AuthenticatedAvatar(
            state: state,
            name: authorName,
            avatarUrl: member?.avatarUrl,
            radius: 20,
            backgroundColor: GcColors.accent,
          ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!grouped)
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        authorName,
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
                    if (!message.deleted && message.sendStatus == null)
                      _MessageActionMenu(
                        message: message,
                        canEdit: message.authorId == state.user?.accountId,
                        canDelete:
                            message.authorId == state.user?.accountId ||
                            state.user?.isAdmin == true,
                        onReply: onReply,
                        mentionOptions: [
                          for (final member in state.members)
                            (member.id, member.displayName),
                        ],
                        selfId: state.user?.accountId ?? '',
                        onEdit: (body, revision, ids) =>
                            state.editTextWithResult(
                              message,
                              body,
                              revision,
                              mentionUserIds: ids,
                            ),
                        onRefresh: () async {
                          final latest = await state.refreshTextMessageRevision(
                            message,
                          );
                          return latest == null
                              ? null
                              : (
                                  revision: latest.revision,
                                  deleted: latest.deleted,
                                );
                        },
                        onDelete: () => state.deleteText(message),
                      ),
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        label: '$authorName, $time',
                        child: const SizedBox.shrink(),
                      ),
                    ),
                    if (!message.deleted && message.sendStatus == null)
                      _MessageActionMenu(
                        message: message,
                        canEdit: message.authorId == state.user?.accountId,
                        canDelete:
                            message.authorId == state.user?.accountId ||
                            state.user?.isAdmin == true,
                        onReply: onReply,
                        mentionOptions: [
                          for (final member in state.members)
                            (member.id, member.displayName),
                        ],
                        selfId: state.user?.accountId ?? '',
                        onEdit: (body, revision, ids) =>
                            state.editTextWithResult(
                              message,
                              body,
                              revision,
                              mentionUserIds: ids,
                            ),
                        onRefresh: () async {
                          final latest = await state.refreshTextMessageRevision(
                            message,
                          );
                          return latest == null
                              ? null
                              : (
                                  revision: latest.revision,
                                  deleted: latest.deleted,
                                );
                        },
                        onDelete: () => state.deleteText(message),
                      ),
                  ],
                ),
              if (!grouped) const SizedBox(height: 4),
              if (replyPreview != null && !message.deleted)
                _ReplyPreview(label: replyPreview!, onTap: onJumpToReply),
              if (message.deleted)
                const Text(
                  'Сообщение удалено',
                  style: TextStyle(
                    color: GcColors.muted,
                    fontSize: 15,
                    height: 1.45,
                    fontStyle: FontStyle.italic,
                  ),
                )
              else
                FormattedMessageBody(body: message.body, color: GcColors.text),
              if (message.sendStatus == MessageSendStatus.sending)
                const Text(
                  'Отправляется…',
                  style: TextStyle(color: GcColors.muted, fontSize: 12),
                ),
              if (message.sendStatus == MessageSendStatus.failed)
                TextButton.icon(
                  onPressed: state.sending ? null : onRetry,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Не отправлено · Повторить отправку'),
                ),
              if (!message.deleted &&
                  message.sendStatus == null &&
                  message.attachments.isNotEmpty)
                MessageAttachmentList(
                  state: state,
                  parentPath:
                      '/channels/${Uri.encodeComponent(message.channelId)}',
                  attachments: message.attachments,
                ),
              if (message.mentionUserIds.isNotEmpty && !message.deleted)
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Text(
                    'Упомянуты: ${message.mentionUserIds.map((id) => _mentionDisplayName(state, id)).join(' ')}',
                    style: const TextStyle(color: GcColors.muted, fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

String _messageSnippet(String body) {
  final flattened = body.replaceAll('\n', ' ').trim();
  return flattened.length <= 140
      ? flattened
      : '${flattened.substring(0, 140)}…';
}

String _searchDateTime(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year} · ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

class _SearchContextMessage {
  const _SearchContextMessage({
    required this.id,
    required this.authorId,
    required this.body,
    required this.createdAt,
    required this.deleted,
    required this.attachments,
    this.editedAt,
  });
  final String id;
  final String authorId;
  final String body;
  final DateTime createdAt;
  final DateTime? editedAt;
  final bool deleted;
  final List<MessageAttachment> attachments;
}

class _MessageActionMenu extends StatelessWidget {
  const _MessageActionMenu({
    required this.message,
    required this.canEdit,
    required this.canDelete,
    required this.onReply,
    required this.mentionOptions,
    required this.selfId,
    required this.onEdit,
    required this.onRefresh,
    required this.onDelete,
  });

  final ChatMessage message;
  final bool canEdit;
  final bool canDelete;
  final ValueChanged<ChatMessage>? onReply;
  final List<(String, String)> mentionOptions;
  final String selfId;
  final Future<MessageEditOutcome> Function(String, int, List<String>) onEdit;
  final Future<({int revision, bool deleted})?> Function() onRefresh;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    tooltip: 'Действия с сообщением',
    onSelected: (action) async {
      if (action == 'reply') {
        onReply?.call(message);
      } else if (action == 'edit') {
        await _editMessageDialog(
          context,
          message.body,
          message.revision,
          message.mentionUserIds,
          mentionOptions,
          selfId,
          onEdit,
          onRefresh,
        );
      } else if (action == 'delete' && await _confirmDelete(context)) {
        await onDelete();
      }
    },
    itemBuilder: (_) => [
      const PopupMenuItem(value: 'reply', child: Text('Ответить')),
      if (canEdit) const PopupMenuItem(value: 'edit', child: Text('Изменить')),
      if (canDelete)
        const PopupMenuItem(value: 'delete', child: Text('Удалить')),
    ],
    icon: const Icon(Icons.more_horiz, size: 18),
  );
}

class _DirectMessageActionMenu extends StatelessWidget {
  const _DirectMessageActionMenu({
    required this.message,
    required this.canEdit,
    required this.onReply,
    required this.mentionOptions,
    required this.selfId,
    required this.onEdit,
    required this.onRefresh,
    required this.onDelete,
  });

  final DirectChatMessage message;
  final bool canEdit;
  final ValueChanged<DirectChatMessage> onReply;
  final List<(String, String)> mentionOptions;
  final String selfId;
  final Future<MessageEditOutcome> Function(String, int, List<String>) onEdit;
  final Future<({int revision, bool deleted})?> Function() onRefresh;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    tooltip: 'Действия с сообщением',
    onSelected: (action) async {
      if (action == 'reply') {
        onReply(message);
      } else if (action == 'edit') {
        await _editMessageDialog(
          context,
          message.body,
          message.revision,
          message.mentionUserIds,
          mentionOptions,
          selfId,
          onEdit,
          onRefresh,
        );
      } else if (action == 'delete' && await _confirmDelete(context)) {
        await onDelete();
      }
    },
    itemBuilder: (_) => [
      const PopupMenuItem(value: 'reply', child: Text('Ответить')),
      if (canEdit) const PopupMenuItem(value: 'edit', child: Text('Изменить')),
      if (canEdit) const PopupMenuItem(value: 'delete', child: Text('Удалить')),
    ],
    icon: const Icon(Icons.more_horiz, size: 18),
  );
}

class _ReplyPreview extends StatelessWidget {
  const _ReplyPreview({required this.label, this.onTap});
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(4),
    child: Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.only(left: 10),
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: GcColors.accentText, width: 2)),
      ),
      child: Text(
        '↪ $label',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: GcColors.textSecondary, fontSize: 12),
      ),
    ),
  );
}

class _ReplyTargetBanner extends StatelessWidget {
  const _ReplyTargetBanner({required this.text, required this.onCancel});
  final String text;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.fromLTRB(10, 5, 4, 5),
    decoration: const BoxDecoration(
      border: Border(left: BorderSide(color: GcColors.accentText, width: 2)),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: GcColors.textSecondary, fontSize: 12),
          ),
        ),
        IconButton(
          tooltip: 'Отменить ответ',
          onPressed: onCancel,
          icon: const Icon(Icons.close, size: 16),
          visualDensity: VisualDensity.compact,
        ),
      ],
    ),
  );
}

class _MentionPicker extends StatelessWidget {
  const _MentionPicker({
    required this.options,
    required this.selfId,
    required this.selectedIds,
    required this.onChanged,
    this.disabled = false,
  });

  final List<(String, String)> options;
  final String selfId;
  final Set<String> selectedIds;
  final ValueChanged<Set<String>> onChanged;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final available = options.where((option) => option.$1 != selfId).toList();
    if (available.isEmpty && selectedIds.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6,
        runSpacing: 4,
        children: [
          PopupMenuButton<String>(
            tooltip: 'Выбрать упоминание',
            enabled: !disabled,
            onSelected: (id) {
              final next = Set<String>.from(selectedIds);
              if (!next.add(id)) {
                next.remove(id);
              }
              onChanged(next);
            },
            itemBuilder: (_) => available
                .where(
                  (option) =>
                      selectedIds.contains(option.$1) ||
                      selectedIds.length < 100,
                )
                .map(
                  (option) => PopupMenuItem<String>(
                    value: option.$1,
                    child: Row(
                      children: [
                        Icon(
                          selectedIds.contains(option.$1)
                              ? Icons.check_box_outlined
                              : Icons.check_box_outline_blank,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(option.$2),
                      ],
                    ),
                  ),
                )
                .toList(),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.alternate_email, size: 17),
                  SizedBox(width: 4),
                  Text('Упомянуть', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ),
          for (final id in selectedIds)
            InputChip(
              label: Text(
                '@${options.where((option) => option.$1 == id).firstOrNull?.$2 ?? id}',
              ),
              onDeleted: () {
                onChanged(selectedIds.where((value) => value != id).toSet());
              },
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}

String _mentionDisplayName(AppState state, String id) {
  final member = state.members
      .where((candidate) => candidate.id == id)
      .firstOrNull;
  return '@${member?.displayName ?? id}';
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

class _WorkspaceSearchPanel extends StatefulWidget {
  const _WorkspaceSearchPanel({required this.state});
  final AppState state;

  @override
  State<_WorkspaceSearchPanel> createState() => _WorkspaceSearchPanelState();
}

class _WorkspaceSearchPanelState extends State<_WorkspaceSearchPanel> {
  final _query = TextEditingController();
  final _scroll = ScrollController();
  String _scope = 'all';
  String _activeQuery = '';
  String? _nextCursor;
  String? _error;
  bool _loading = false;
  bool _searched = false;
  int _sequence = 0;
  List<SearchMessage> _results = const [];

  @override
  void initState() {
    super.initState();
    _query.addListener(_queryChanged);
  }

  void _queryChanged() {
    if (mounted) setState(() {});
  }

  bool get _canLoadMore =>
      _nextCursor != null && !_loading && _query.text.trim() == _activeQuery;

  AppState get state => widget.state;

  ({String id, String label, bool direct})? _currentConversation() {
    final direct = state.selectedDirectMessage;
    if (direct != null) {
      return (id: direct.id, label: direct.displayName, direct: true);
    }
    final channel = state.selectedChannel;
    if (channel?.kind == ChannelKind.text) {
      return (id: channel!.id, label: '# ${channel.name}', direct: false);
    }
    return null;
  }

  void _reset() {
    _sequence++;
    _results = const [];
    _nextCursor = null;
    _activeQuery = '';
    _error = null;
    _loading = false;
    _searched = false;
  }

  Future<void> _search({String? before}) async {
    final query = (before == null ? _query.text : _activeQuery).trim();
    if (query.isEmpty) {
      setState(() => _error = 'Введите поисковый запрос.');
      return;
    }
    if (query.runes.length > 256) {
      setState(() => _error = 'Запрос должен содержать до 256 символов.');
      return;
    }
    final current = _currentConversation();
    if (_scope == 'current' && current == null) {
      setState(() => _error = 'Выберите текстовый канал или личный диалог.');
      return;
    }
    final sequence = ++_sequence;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await state.api.searchMessages(
        query,
        channelId: _scope == 'current' && current?.direct == false
            ? current!.id
            : null,
        directMessageId: _scope == 'current' && current?.direct == true
            ? current!.id
            : null,
        before: before,
        limit: 20,
      );
      if (!mounted || sequence != _sequence) return;
      setState(() {
        _results = before == null
            ? page.messages
            : [..._results, ...page.messages];
        _nextCursor = page.nextCursor;
        _activeQuery = query;
        _searched = true;
      });
    } catch (cause) {
      if (mounted && sequence == _sequence) {
        setState(() {
          _error = cause is ApiFailure
              ? cause.message
              : 'Не удалось выполнить поиск сообщений.';
        });
      }
    } finally {
      if (mounted && sequence == _sequence) {
        setState(() => _loading = false);
      }
    }
  }

  String _conversationLabel(SearchMessage message) {
    if (message.kind == SearchMessageKind.directMessage) {
      return state.directMessages
              .where((value) => value.id == message.conversationId)
              .firstOrNull
              ?.displayName ??
          'Личный диалог';
    }
    final channel = state.topology?.categories
        .expand((category) => category.channels)
        .where((value) => value.id == message.conversationId)
        .firstOrNull;
    return channel == null ? 'Текстовый канал' : '# ${channel.name}';
  }

  @override
  void dispose() {
    _sequence++;
    _query.removeListener(_queryChanged);
    _query.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final current = _currentConversation();
    if (_scope == 'current' && current == null) _scope = 'all';
    return Column(
      children: [
        SizedBox(
          height: 64,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: GcColors.border)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  const Icon(Icons.search, color: GcColors.muted, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Поиск сообщений',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: GcColors.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Закрыть поиск',
                    onPressed: state.closeSearchPanel,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 720;
              final queryField = TextField(
                controller: _query,
                autofocus: true,
                enabled: !_loading,
                maxLength: 256,
                buildCounter: (
                  _, {
                  required currentLength,
                  required isFocused,
                  maxLength,
                }) => null,
                onSubmitted: (_) => _search(),
                decoration: InputDecoration(
                  hintText: 'Слова или «точная фраза»',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    tooltip: 'Очистить запрос',
                    onPressed: _query.clear,
                    icon: const Icon(Icons.close),
                  ),
                ),
              );
              final scopeField = DropdownButtonFormField<String>(
                initialValue: _scope,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Область поиска'),
                items: [
                  const DropdownMenuItem(
                    value: 'all',
                    child: Text('Все беседы'),
                  ),
                  if (current != null)
                    DropdownMenuItem(
                      value: 'current',
                      child: Text(
                        'Текущая беседа: ${current.label}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: _loading
                    ? null
                    : (value) {
                        if (value == null) return;
                        setState(() {
                          _scope = value;
                          _reset();
                        });
                      },
              );
              final searchButton = FilledButton.icon(
                onPressed: _loading ? null : () => _search(),
                icon: _loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.search),
                label: Text(_loading ? 'Ищем…' : 'Найти'),
              );
              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    queryField,
                    const SizedBox(height: 8),
                    scopeField,
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: searchButton,
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(flex: 2, child: queryField),
                  const SizedBox(width: 12),
                  Expanded(child: scopeField),
                  const SizedBox(width: 10),
                  searchButton,
                ],
              );
            },
          ),
        ),
        if (_error case final error?)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Semantics(
                liveRegion: true,
                child: Text(
                  error,
                  style: const TextStyle(color: GcColors.danger),
                ),
              ),
            ),
          ),
        if (_nextCursor != null && !_canLoadMore)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Измените запрос или запустите поиск заново.',
                style: TextStyle(color: GcColors.muted, fontSize: 12),
              ),
            ),
          ),
        Expanded(
          child: _results.isEmpty
              ? Center(
                  child: Semantics(
                    liveRegion: true,
                    label: _loading
                        ? 'Ищем сообщения…'
                        : _searched
                        ? 'Совпадений нет.'
                        : 'Введите запрос и нажмите «Найти».',
                    child: Text(
                      _loading
                          ? 'Ищем сообщения…'
                          : _searched
                          ? 'Совпадений нет.'
                          : 'Введите запрос и нажмите «Найти».',
                      style: const TextStyle(color: GcColors.muted),
                    ),
                  ),
                )
              : ListView.separated(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                  itemCount: _results.length + (_nextCursor == null ? 0 : 1),
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    if (index == _results.length) {
                      return Center(
                        child: TextButton(
                          onPressed: !_canLoadMore
                              ? null
                              : () => _search(before: _nextCursor),
                          child: const Text('Показать ещё'),
                        ),
                      );
                    }
                    final message = _results[index];
                    final author =
                        state.members
                            .where((member) => member.id == message.authorId)
                            .firstOrNull
                            ?.displayName ??
                        message.authorId;
                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final narrow = constraints.maxWidth < 400;
                        final metadata = Text(
                          '${_searchDateTime(message.createdAt)} · $author',
                          maxLines: narrow ? 2 : 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: GcColors.muted,
                            fontSize: 12,
                          ),
                        );
                        final conversation = Text(
                          _conversationLabel(message),
                          maxLines: narrow ? 1 : 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        );
                        return Card(
                          color: GcColors.surface,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (narrow) ...[
                                  conversation,
                                  const SizedBox(height: 4),
                                  metadata,
                                ] else
                                  Row(
                                    children: [
                                      Expanded(child: conversation),
                                      const SizedBox(width: 8),
                                      Flexible(child: metadata),
                                    ],
                                  ),
                                const SizedBox(height: 8),
                                FormattedMessageBody(
                                  body: message.body,
                                  color: GcColors.text,
                                ),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton.icon(
                                    onPressed: () =>
                                        state.openSearchContext(message),
                                    icon: const Icon(
                                      Icons.open_in_new,
                                      size: 17,
                                    ),
                                    label: const Text('Открыть сообщение'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _SearchMessageContext extends StatefulWidget {
  const _SearchMessageContext({required this.state});
  final AppState state;

  @override
  State<_SearchMessageContext> createState() => _SearchMessageContextState();
}

class _SearchMessageContextState extends State<_SearchMessageContext> {
  final _targetKey = GlobalKey();
  String? _lastTargetId;

  @override
  Widget build(BuildContext context) {
    final target = widget.state.searchContextMessage;
    final isDirect = target?.kind == SearchMessageKind.directMessage;
    final List<_SearchContextMessage> messages = isDirect
        ? widget.state.searchContextDirectMessages
              .map(
                (message) => _SearchContextMessage(
                  id: message.id,
                  authorId: message.authorId,
                  body: message.body,
                  createdAt: message.createdAt,
                  editedAt: message.editedAt,
                  deleted: message.deleted,
                  attachments: message.attachments,
                ),
              )
              .toList(growable: false)
        : widget.state.searchContextTextMessages
              .map(
                (message) => _SearchContextMessage(
                  id: message.id,
                  authorId: message.authorId,
                  body: message.body,
                  createdAt: message.createdAt,
                  editedAt: message.editedAt,
                  deleted: message.deleted,
                  attachments: message.attachments,
                ),
              )
              .toList(growable: false);
    if (target != null && target.id != _lastTargetId) {
      _lastTargetId = target.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final targetContext = _targetKey.currentContext;
        if (targetContext != null) {
          Scrollable.ensureVisible(
            targetContext,
            alignment: .35,
            duration: const Duration(milliseconds: 250),
          );
        }
      });
    }
    return Column(
      children: [
        _Header(
          icon: Icons.manage_search,
          title: 'Контекст найденного сообщения',
          subtitle: target == null
              ? ''
              : isDirect
              ? widget.state.selectedDirectMessage?.displayName ??
                    'Личный диалог'
              : '# ${widget.state.selectedChannel?.name ?? 'Текстовый канал'}',
          trailing: TextButton.icon(
            onPressed: widget.state.returnFromSearchContext,
            icon: const Icon(Icons.arrow_back, size: 18),
            label: const Text('Вернуться к беседе'),
          ),
        ),
        if (widget.state.searchContextError case final error?)
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(error, style: const TextStyle(color: GcColors.danger)),
                  const SizedBox(height: 8),
                  if (target != null)
                    TextButton(
                      onPressed: () => widget.state.openSearchContext(target),
                      child: const Text('Повторить'),
                    ),
                ],
              ),
            ),
          )
        else if (widget.state.loadingSearchContext)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              itemCount: messages.length,
              separatorBuilder: (_, index) {
                final before = messages[index];
                final after = messages[index + 1];
                return SizedBox(
                  height: before.authorId == after.authorId ? 6 : 18,
                );
              },
              itemBuilder: (context, index) {
                final message = messages[index];
                final authorId = message.authorId;
                final authorName = _mentionDisplayName(
                  widget.state,
                  authorId,
                ).substring(1);
                final isTarget = message.id == target?.id;
                final createdAt = message.createdAt;
                final body = message.body;
                final deleted = message.deleted;
                final attachments = message.attachments;
                final conversationId = isDirect
                    ? widget.state.selectedDirectMessage?.id
                    : widget.state.selectedChannel?.id;
                return Container(
                  key: isTarget ? _targetKey : null,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isTarget ? GcColors.selected : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: isTarget
                        ? Border.all(color: GcColors.accentText)
                        : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$authorName · ${_searchDateTime(createdAt)}${message.editedAt == null ? '' : ' · изменено'}',
                        style: const TextStyle(
                          color: GcColors.muted,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 5),
                      if (deleted)
                        const Text(
                          'Сообщение удалено.',
                          style: TextStyle(
                            color: GcColors.muted,
                            fontStyle: FontStyle.italic,
                          ),
                        )
                      else ...[
                        FormattedMessageBody(body: body, color: GcColors.text),
                        if (attachments.isNotEmpty && conversationId != null)
                          MessageAttachmentList(
                            state: widget.state,
                            parentPath: isDirect
                                ? '/direct-messages/${Uri.encodeComponent(conversationId)}'
                                : '/channels/${Uri.encodeComponent(conversationId)}',
                            attachments: attachments,
                          ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _DirectConversation extends StatefulWidget {
  const _DirectConversation({
    required this.state,
    required this.conversation,
    this.onToggleNavigation,
    this.onOpenMembers,
  });
  final AppState state;
  final DirectConversation conversation;
  final VoidCallback? onToggleNavigation;
  final VoidCallback? onOpenMembers;

  @override
  State<_DirectConversation> createState() => _DirectConversationState();
}

class _DirectConversationState extends State<_DirectConversation> {
  final _controller = TextEditingController();
  final _composerFocus = FocusNode();
  final _attachmentComposerKey = GlobalKey<MessageAttachmentComposerState>();
  final _scroll = ScrollController();
  DirectChatMessage? _replyTarget;
  final Set<String> _mentionUserIds = {};
  List<MessageAttachment> _attachments = const [];
  bool _attachmentsPending = false;

  Future<void> _pasteFromClipboard() async {
    await _attachmentComposerKey.currentState?.pasteFromClipboard();
  }

  @override
  void didUpdateWidget(covariant _DirectConversation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.conversation.id != widget.conversation.id) {
      _replyTarget = null;
      _mentionUserIds.clear();
      _attachments = const [];
      _attachmentsPending = false;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _composerFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadOlderDirect() async {
    if (!_scroll.hasClients) return;
    final oldOffset = _scroll.position.pixels;
    final oldExtent = _scroll.position.maxScrollExtent;
    if (!await widget.state.loadOlderDirectMessages() || !mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final position = _scroll.position;
      position.jumpTo(
        (oldOffset + position.maxScrollExtent - oldExtent).clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        ),
      );
    });
  }

  Future<void> _send() async {
    if (widget.state.sending || _attachmentsPending) return;
    final body = _controller.text;
    final replyId = _replyTarget?.id;
    final mentionIds = _mentionUserIds.toSet();
    final attachmentIds = _attachments.map((item) => item.id).toList();
    final sent = await widget.state.sendDirect(
      body,
      replyToId: replyId,
      mentionUserIds: _mentionUserIds.toList(),
      attachments: _attachments,
    );
    if (!sent ||
        !mounted ||
        widget.state.selectedDirectMessage?.id != widget.conversation.id) {
      return;
    }
    if (_controller.text != body ||
        _replyTarget?.id != replyId ||
        !setEquals(_mentionUserIds, mentionIds) ||
        !listEquals(
          _attachments.map((item) => item.id).toList(),
          attachmentIds,
        )) {
      return;
    }
    _controller.clear();
    setState(() {
      _replyTarget = null;
      _mentionUserIds.clear();
      _attachments = const [];
    });
  }

  Future<void> _retry(DirectChatMessage message) async {
    final body = _controller.text;
    final replyId = _replyTarget?.id;
    final mentionIds = _mentionUserIds.toSet();
    final attachmentIds = _attachments.map((item) => item.id).toList();
    final sent = await widget.state.retryDirectSend(message.clientMessageId!);
    if (!sent ||
        !mounted ||
        widget.state.selectedDirectMessage?.id != widget.conversation.id ||
        body.trim() != message.body ||
        _controller.text != body ||
        replyId != message.replyToId ||
        _replyTarget?.id != replyId ||
        !setEquals(mentionIds, message.mentionUserIds.toSet()) ||
        !setEquals(_mentionUserIds, mentionIds) ||
        !listEquals(
          attachmentIds,
          message.attachments.map((item) => item.id).toList(),
        ) ||
        !listEquals(
          _attachments.map((item) => item.id).toList(),
          attachmentIds,
        )) {
      return;
    }
    _controller.clear();
    setState(() {
      _replyTarget = null;
      _mentionUserIds.clear();
      _attachments = const [];
    });
  }

  String _directAuthorName(String accountId) {
    if (accountId == widget.state.user?.accountId) {
      return widget.state.profile?.displayName ?? 'Вы';
    }
    if (accountId == widget.conversation.participantId) {
      return widget.conversation.displayName;
    }
    return _mentionDisplayName(widget.state, accountId).substring(1);
  }

  String? _directReplyLabel(DirectChatMessage message) {
    final preview = message.replyPreview;
    if (preview != null) {
      if (preview.deleted) return 'Сообщение удалено';
      return '${_directAuthorName(preview.authorId)}: ${_messageSnippet(preview.body)}';
    }
    final replyToId = message.replyToId;
    if (replyToId == null) return null;
    final target = widget.state.directMessageHistory
        .where((candidate) => candidate.id == replyToId)
        .firstOrNull;
    if (target == null) return 'Исходное сообщение недоступно';
    if (target.deleted) return 'Сообщение удалено';
    return '${_directAuthorName(target.authorId)}: ${_messageSnippet(target.body)}';
  }

  void _replyToDirect(DirectChatMessage message) {
    setState(() => _replyTarget = message);
    _composerFocus.requestFocus();
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
          onToggleNavigation: widget.onToggleNavigation,
          onOpenMembers: widget.onOpenMembers,
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
                  controller: _scroll,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 24,
                  ),
                  itemCount:
                      widget.state.directMessageHistory.length +
                      (widget.state.nextDirectMessageCursor == null ? 0 : 1),
                  itemBuilder: (context, index) {
                    if (widget.state.nextDirectMessageCursor != null &&
                        index == 0) {
                      return Center(
                        child: TextButton.icon(
                          onPressed: widget.state.loadingOlderDirectMessages
                              ? null
                              : _loadOlderDirect,
                          icon: widget.state.loadingOlderDirectMessages
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.history),
                          label: Text(
                            widget.state.loadingOlderDirectMessages
                                ? 'Загружаем…'
                                : 'Загрузить предыдущие сообщения',
                          ),
                        ),
                      );
                    }
                    final messageIndex =
                        index -
                        (widget.state.nextDirectMessageCursor == null ? 0 : 1);
                    final message =
                        widget.state.directMessageHistory[messageIndex];
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_directReplyLabel(message) case final label?)
                                _ReplyPreview(label: label),
                              if (message.deleted)
                                const Text(
                                  'Сообщение удалено',
                                  style: TextStyle(
                                    color: GcColors.muted,
                                    fontStyle: FontStyle.italic,
                                  ),
                                )
                              else
                                FormattedMessageBody(
                                  body: message.body,
                                  color: GcColors.text,
                                  fontSize: 14,
                                  lineHeight: 1.4,
                                ),
                              if (message.sendStatus ==
                                  MessageSendStatus.sending)
                                const Text(
                                  'Отправляется…',
                                  style: TextStyle(
                                    color: GcColors.muted,
                                    fontSize: 12,
                                  ),
                                ),
                              if (message.sendStatus ==
                                  MessageSendStatus.failed)
                                TextButton.icon(
                                  onPressed: widget.state.sending
                                      ? null
                                      : () => _retry(message),
                                  icon: const Icon(Icons.refresh, size: 16),
                                  label: const Text(
                                    'Не отправлено · Повторить отправку',
                                  ),
                                ),
                              if (!message.deleted &&
                                  message.sendStatus == null &&
                                  message.attachments.isNotEmpty)
                                MessageAttachmentList(
                                  state: widget.state,
                                  parentPath:
                                      '/direct-messages/${Uri.encodeComponent(message.directMessageId)}',
                                  attachments: message.attachments,
                                ),
                              if (message.mentionUserIds.isNotEmpty &&
                                  !message.deleted) ...[
                                const SizedBox(height: 5),
                                Text(
                                  'Упомянуты: ${message.mentionUserIds.map((id) => _mentionDisplayName(widget.state, id)).join(' ')}',
                                  style: const TextStyle(
                                    color: GcColors.muted,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (!message.deleted && message.sendStatus == null)
                          _DirectMessageActionMenu(
                            message: message,
                            canEdit: own,
                            onReply: _replyToDirect,
                            mentionOptions: [
                              (
                                widget.conversation.participantId,
                                widget.conversation.displayName,
                              ),
                            ],
                            selfId: widget.state.user?.accountId ?? '',
                            onEdit: (body, revision, ids) =>
                                widget.state.editDirectWithResult(
                                  message,
                                  body,
                                  revision,
                                  mentionUserIds: ids,
                                ),
                            onRefresh: () async {
                              final latest = await widget.state
                                  .refreshDirectMessageRevision(message);
                              return latest == null
                                  ? null
                                  : (
                                      revision: latest.revision,
                                      deleted: latest.deleted,
                                    );
                            },
                            onDelete: () => widget.state.deleteDirect(message),
                          ),
                      ],
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_replyTarget != null)
                _ReplyTargetBanner(
                  text:
                      'Ответ для ${_directAuthorName(_replyTarget!.authorId)}',
                  onCancel: () => setState(() => _replyTarget = null),
                ),
              _MentionPicker(
                options: [
                  (
                    widget.conversation.participantId,
                    widget.conversation.displayName,
                  ),
                ],
                selfId: widget.state.user?.accountId ?? '',
                selectedIds: _mentionUserIds,
                onChanged: (ids) => setState(() {
                  _mentionUserIds
                    ..clear()
                    ..addAll(ids);
                }),
              ),
              MessageAttachmentComposer(
                key: _attachmentComposerKey,
                state: widget.state,
                attachments: _attachments,
                textController: _controller,
                focusNode: _composerFocus,
                directMessageId: widget.conversation.id,
                onChanged: (attachments) => setState(() {
                  _attachments = attachments;
                }),
                onPending: (pending) => setState(() {
                  _attachmentsPending = pending;
                }),
              ),
              CallbackShortcuts(
                bindings: {
                  const SingleActivator(LogicalKeyboardKey.enter): _send,
                  const SingleActivator(LogicalKeyboardKey.keyV, control: true):
                      _pasteFromClipboard,
                  const SingleActivator(LogicalKeyboardKey.keyV, meta: true):
                      _pasteFromClipboard,
                  const SingleActivator(LogicalKeyboardKey.insert, shift: true):
                      _pasteFromClipboard,
                },
                child: TextField(
                  focusNode: _composerFocus,
                  controller: _controller,
                  contextMenuBuilder: (context, editableTextState) =>
                      _messageContextMenu(
                        context,
                        editableTextState,
                        _pasteFromClipboard,
                      ),
                  enabled: !widget.state.sending,
                  maxLength: 8000,
                  minLines: 1,
                  maxLines: 5,
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText:
                        'Сообщение для ${widget.conversation.displayName}…',
                    suffixIcon: IconButton(
                      tooltip: 'Отправить личное сообщение',
                      onPressed: widget.state.sending || _attachmentsPending
                          ? null
                          : _send,
                      icon: const Icon(Icons.send_outlined),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _VoiceRoom extends StatefulWidget {
  const _VoiceRoom({
    super.key,
    required this.state,
    required this.channel,
    this.onToggleNavigation,
    this.onOpenMembers,
  });
  final AppState state;
  final GuildChannel channel;
  final VoidCallback? onToggleNavigation;
  final VoidCallback? onOpenMembers;

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
        final selectedScreenPublication = selectedScreen?.videoTrackPublications
            .where(
              (publication) =>
                  publication.source == TrackSource.screenShareVideo,
            )
            .firstOrNull;
        final selectedTrack = selectedScreenPublication?.track as VideoTrack?;
        final localScreenPublication =
            state.screenSharePhase == ScreenSharePhase.sharing
            ? room?.localParticipant?.getTrackPublicationBySource(
                TrackSource.screenShareVideo,
              )
            : null;
        final localScreenTrack = localScreenPublication?.track as VideoTrack?;
        final selectedAudioPublication = selectedScreen?.audioTrackPublications
            .where(
              (publication) =>
                  publication.source == TrackSource.screenShareAudio,
            )
            .firstOrNull;
        final participantCount = active ? participants.length + 1 : 0;
        final showingLocalScreen =
            selectedTrack == null &&
            localScreenTrack != null &&
            _selectedScreenIdentity == null;
        final viewerTrack =
            selectedTrack ?? (showingLocalScreen ? localScreenTrack : null);
        final selectedName = selectedScreen != null
            ? _participantName(selectedScreen)
            : showingLocalScreen
            ? 'ваш экран'
            : null;
        return Column(
          children: [
            _Header(
              icon: Icons.volume_up_outlined,
              title: channel.name,
              onToggleNavigation: widget.onToggleNavigation,
              onOpenMembers: widget.onOpenMembers,
              subtitle: selectedName != null
                  ? 'Демонстрация $selectedName'
                  : active
                  ? state.voicePhase == VoicePhase.reconnecting
                        ? 'Восстанавливаем связь · состояние микрофона сохранено'
                        : 'Голосовой канал · участников: $participantCount'
                  : channel.admissionClosed
                  ? 'Вход временно закрыт'
                  : 'Голосовой канал · подключитесь, чтобы увидеть участников',
              trailing: active
                  ? IconButton(
                      tooltip:
                          state.screenSharePhase == ScreenSharePhase.sharing
                          ? 'Остановить демонстрацию экрана'
                          : 'Начать демонстрацию экрана',
                      onPressed: switch (state.screenSharePhase) {
                        ScreenSharePhase.starting ||
                        ScreenSharePhase.stopping => null,
                        ScreenSharePhase.sharing => state.stopScreenShare,
                        _ => () => _toggleLocalScreenShare(state),
                      },
                      icon:
                          state.screenSharePhase == ScreenSharePhase.starting ||
                              state.screenSharePhase ==
                                  ScreenSharePhase.stopping
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              state.screenSharePhase == ScreenSharePhase.sharing
                                  ? Icons.stop_screen_share_outlined
                                  : Icons.screen_share_outlined,
                            ),
                    )
                  : null,
            ),
            if (active && state.screenShareError != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: _ErrorBanner(message: state.screenShareError!),
              ),
            Expanded(
              child: active
                  ? viewerTrack != null
                        ? _VoiceScreenViewer(
                            state: state,
                            track: viewerTrack,
                            publisherName: selectedName!,
                            screens: screens,
                            selectedIdentity: _selectedScreenIdentity,
                            localScreenAvailable: localScreenTrack != null,
                            showingLocalScreen: showingLocalScreen,
                            receiverTrack: selectedTrack is RemoteVideoTrack
                                ? selectedTrack
                                : null,
                            sourceTrackName: showingLocalScreen
                                ? localScreenPublication?.name
                                : selectedScreenPublication?.name,
                            localName:
                                state.profile?.displayName.trim().isNotEmpty ==
                                    true
                                ? state.profile!.displayName
                                : 'Вы',
                            localMuted: state.microphoneMuted,
                            localSpeaking:
                                room?.localParticipant?.isSpeaking ?? false,
                            participants: participants,
                            screenAudioAvailable:
                                !showingLocalScreen &&
                                selectedAudioPublication != null,
                            screenAudioVolume:
                                showingLocalScreen ||
                                    selectedAudioPublication == null ||
                                    selectedScreen == null
                                ? null
                                : state.screenShareVolume(selectedScreen),
                            deafened: state.deafened,
                            onScreenAudioVolumeChanged:
                                selectedScreen == null || showingLocalScreen
                                ? null
                                : (level) => unawaited(
                                    state.setScreenShareVolume(
                                      selectedScreen,
                                      level,
                                    ),
                                  ),
                            onFullscreen: () => unawaited(
                              _openScreenFullscreen(
                                track: viewerTrack,
                                publisherName: selectedName,
                              ),
                            ),
                            onClose: () =>
                                setState(() => _selectedScreenIdentity = ''),
                            onScreenSelected: (identity) => setState(
                              () => _selectedScreenIdentity = identity,
                            ),
                          )
                        : _selectedScreenIdentity?.isNotEmpty == true
                        ? VoiceScreenEndedView(
                            choices: [
                              if (localScreenTrack != null)
                                VoiceScreenChoice(
                                  identity: null,
                                  label: 'Ваш экран',
                                  selected: false,
                                  isLocal: true,
                                  avatarIdentity: state.user?.accountId,
                                  avatarLabel:
                                      state.profile?.displayName ?? 'Вы',
                                ),
                              for (final participant in screens)
                                VoiceScreenChoice(
                                  identity: participant.identity,
                                  label: _participantName(participant),
                                  selected: false,
                                  accountId: _voiceParticipantAccountId(
                                    participant,
                                  ),
                                  avatarLabel: _participantName(participant),
                                  hasAudio: participant.audioTrackPublications
                                      .any(
                                        (publication) =>
                                            publication.source ==
                                                TrackSource.screenShareAudio &&
                                            publication.track != null,
                                      ),
                                ),
                            ],
                            participants: _VoiceParticipantStrip(
                              state: state,
                              localName:
                                  state.profile?.displayName
                                          .trim()
                                          .isNotEmpty ==
                                      true
                                  ? state.profile!.displayName
                                  : 'Вы',
                              localAvatarUrl: state.profile?.avatarUrl,
                              localMuted: state.microphoneMuted,
                              localSpeaking:
                                  room?.localParticipant?.isSpeaking ?? false,
                              participants: participants,
                            ),
                            onScreenSelected: (identity) => setState(
                              () => _selectedScreenIdentity = identity,
                            ),
                            onReturnToParticipants: () =>
                                setState(() => _selectedScreenIdentity = ''),
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

  Future<void> _toggleLocalScreenShare(AppState state) async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await state.startScreenShare();
      return;
    }
    final selection = await ScreenShareSetupDialog.show(
      context,
      initialQuality: state.screenShareQuality,
      allowSourceSelection: defaultTargetPlatform != TargetPlatform.android,
    );
    if (!mounted || selection == null) return;
    await state.startScreenShare(
      sourceId: selection.sourceId,
      quality: selection.quality,
    );
  }

  Future<void> _openScreenFullscreen({
    required VideoTrack track,
    required String publisherName,
  }) async {
    ScreenFullscreenPresentation? presentation;
    try {
      presentation = await ScreenFullscreenPresentation.enter();
      if (!mounted) return;
      await showGeneralDialog<void>(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Закрыть полноэкранный режим',
        barrierColor: Colors.black,
        transitionDuration: const Duration(milliseconds: 160),
        pageBuilder: (dialogContext, _, _) => ScreenFullscreenOverlay(
          publisherName: publisherName,
          video: VideoTrackRenderer(track, renderMode: VideoRenderMode.auto),
          onClose: () => Navigator.of(dialogContext).pop(),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Не удалось развернуть демонстрацию на весь экран.'),
          ),
        );
      }
    } finally {
      await presentation?.restore();
    }
  }
}

String _participantName(RemoteParticipant participant) =>
    participant.name.trim().isNotEmpty
    ? participant.name
    : participant.identity;

GuildMember? _participantMember(AppState state, RemoteParticipant participant) {
  final metadata = participant.metadata;
  if (metadata == null || !metadata.startsWith('account:')) return null;
  final accountId = metadata.substring('account:'.length);
  return state.members.where((member) => member.id == accountId).firstOrNull;
}

bool _participantMuted(RemoteParticipant participant) {
  final publications = participant.audioTrackPublications;
  return publications.isEmpty || publications.every((item) => item.muted);
}

class _VoicePrejoinCard extends StatelessWidget {
  const _VoicePrejoinCard({required this.state, required this.channel});

  final AppState state;
  final GuildChannel channel;

  bool get _joining => state.voicePhase == VoicePhase.joining;
  String get _title =>
      _joining ? 'Подключаемся к голосовой комнате' : 'Вы не подключены';

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
                Semantics(
                  container: true,
                  liveRegion: true,
                  label: _title,
                  child: Text(
                    _title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _joining ? 'Соединение устанавливается.' : 'Посмотрите, кто сейчас в комнате, и выберите удобный способ подключения.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: GcColors.textSecondary,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 20),
                _VoiceRosterPreview(
                  roster: state.voiceRosters
                      ?.where((item) => item.channelId == channel.id)
                      .firstOrNull,
                  error: state.voiceRosterError,
                ),
                if (state.error != null) ...[
                  const SizedBox(height: 20),
                  Semantics(
                    liveRegion: true,
                    child: Container(
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
                  ),
                ],
                const SizedBox(height: 24),
                if (state.transferRequired) ...[
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: state.voicePhase == VoicePhase.joining
                          ? null
                          : () => state.joinVoice(channel, transfer: true),
                      icon: const Icon(Icons.move_up_outlined),
                      label: const Text('Перенести подключение'),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed:
                        channel.admissionClosed ||
                            state.voicePhase == VoicePhase.joining
                        ? null
                        : () => state.joinVoice(channel),
                    icon: state.voicePhase == VoicePhase.joining
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.login),
                    label: Text(
                      channel.admissionClosed
                          ? 'Вход временно закрыт'
                          : state.voicePhase == VoicePhase.joining
                          ? 'Подключаемся…'
                          : 'Подключиться к голосу',
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed:
                        channel.admissionClosed ||
                            state.voicePhase == VoicePhase.joining
                        ? null
                        : () => state.joinVoice(channel, listenerOnly: true),
                    icon: const Icon(Icons.headset_outlined),
                    label: const Text('Подключиться без микрофона'),
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

class _VoiceRosterPreview extends StatelessWidget {
  const _VoiceRosterPreview({required this.roster, required this.error});

  final VoiceRoomRoster? roster;
  final String? error;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: GcColors.raised,
      borderRadius: BorderRadius.circular(GcRadii.md),
      border: Border.all(color: GcColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          roster == null
              ? 'Участники голосового канала'
              : 'Сейчас в канале: ${roster!.participants.length}',
          style: const TextStyle(
            color: GcColors.text,
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        if (roster == null)
          Text(
            error == null
                ? 'Проверяем, кто сейчас в комнате…'
                : 'Не удалось обновить состав комнаты. Повторяем попытку.',
            style: TextStyle(
              color: error == null ? GcColors.muted : GcColors.warning,
              fontSize: 12,
            ),
          )
        else if (roster!.participants.isEmpty)
          const Text(
            'Пока никого нет.',
            style: TextStyle(color: GcColors.muted, fontSize: 13),
          )
        else ...[
          for (var index = 0; index < roster!.participants.length; index++) ...[
            if (index > 0) const SizedBox(height: 8),
            _VoiceRosterMemberRow(participant: roster!.participants[index]),
          ],
        ],
      ],
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
  final ValueChanged<String?> onScreenSelected;

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
                    Text(
                      state.voicePhase == VoicePhase.reconnecting
                          ? 'Восстанавливаем связь'
                          : 'Все в сборе',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      state.voicePhase == VoicePhase.reconnecting
                          ? 'Состояние микрофона сохранено.'
                          : '${participants.length + 1} ${_peopleWord(participants.length + 1)} в комнате'
                                '${screens.isEmpty ? '' : ' · демонстраций: ${screens.length}'}',
                      style: const TextStyle(color: GcColors.textSecondary),
                    ),
                  ],
                ),
              ),
              VoiceConnectionBadge(
                reconnecting: state.voicePhase == VoicePhase.reconnecting,
              ),
            ],
          ),
          if (state.error != null) ...[
            const SizedBox(height: 18),
            Semantics(
              liveRegion: true,
              child: _ErrorBanner(message: state.error!),
            ),
          ],
          if (state.microphoneUnavailable) ...[
            const SizedBox(height: 14),
            VoiceMicrophoneUnavailableNotice(
              onRetry: state.audioActivationMode == AudioActivationMode.ptt
                  ? null
                  : () => unawaited(state.toggleMicrophone()),
            ),
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
            childAspectRatio:
                screens.isNotEmpty ||
                    state.screenSharePhase == ScreenSharePhase.sharing
                ? constraints.maxWidth < 460
                      ? 1.65
                      : 1.2
                : constraints.maxWidth < 460
                ? 2.25
                : 1.45,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _VoiceParticipantCard(
                state: state,
                name: state.profile?.displayName.trim().isNotEmpty == true
                    ? state.profile!.displayName
                    : 'Вы',
                avatarUrl: state.profile?.avatarUrl,
                muted: state.microphoneMuted,
                microphoneUnavailable: state.microphoneUnavailable,
                deafened: state.deafened,
                speaking: room?.localParticipant?.isSpeaking ?? false,
                isLocal: true,
                hasScreen: state.screenSharePhase == ScreenSharePhase.sharing,
                onScreenTap: state.screenSharePhase == ScreenSharePhase.sharing
                    ? () => onScreenSelected(null)
                    : null,
              ),
              for (final participant in participants)
                _VoiceParticipantCard(
                  state: state,
                  name: _participantName(participant),
                  avatarUrl: _participantMember(state, participant)?.avatarUrl,
                  muted: _participantMuted(participant),
                  speaking: participant.isSpeaking,
                  volume: state.participantVolume(participant),
                  onVolumeChanged: state.participantVolume(participant) == null
                      ? null
                      : (level) => unawaited(
                          state.setParticipantVolume(participant, level),
                        ),
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
    required this.state,
    required this.track,
    required this.publisherName,
    required this.screens,
    required this.selectedIdentity,
    required this.localScreenAvailable,
    required this.showingLocalScreen,
    required this.receiverTrack,
    required this.sourceTrackName,
    required this.localName,
    required this.localMuted,
    required this.localSpeaking,
    required this.participants,
    required this.screenAudioAvailable,
    required this.screenAudioVolume,
    required this.deafened,
    required this.onScreenAudioVolumeChanged,
    required this.onFullscreen,
    required this.onClose,
    required this.onScreenSelected,
  });

  final AppState state;
  final VideoTrack track;
  final String publisherName;
  final List<RemoteParticipant> screens;
  final String? selectedIdentity;
  final bool localScreenAvailable;
  final bool showingLocalScreen;
  final RemoteVideoTrack? receiverTrack;
  final String? sourceTrackName;
  final String localName;
  final bool localMuted;
  final bool localSpeaking;
  final List<RemoteParticipant> participants;
  final bool screenAudioAvailable;
  final int? screenAudioVolume;
  final bool deafened;
  final ValueChanged<int>? onScreenAudioVolumeChanged;
  final VoidCallback onFullscreen;
  final VoidCallback onClose;
  final ValueChanged<String?> onScreenSelected;

  @override
  Widget build(BuildContext context) => VoiceViewerLayout(
    stage: Container(
      color: const Color(0xFF080A0E),
      child: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(16),
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
            right: 76,
            top: 28,
            child: IconButton.filledTonal(
              tooltip: 'Развернуть демонстрацию на весь экран',
              onPressed: onFullscreen,
              icon: const Icon(Icons.fullscreen_outlined),
            ),
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
        ],
      ),
    ),
    diagnostics: Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: ScreenReceiverDiagnostics(
        track: receiverTrack,
        isLocal: showingLocalScreen,
        hasAudio: screenAudioAvailable,
        sourceTrackName: sourceTrackName,
      ),
    ),
    audioControls: _audioControls,
    streamRail: _streamRail,
    participants: _VoiceParticipantStrip(
      state: state,
      localName: localName,
      localAvatarUrl: state.profile?.avatarUrl,
      localMuted: localMuted,
      localSpeaking: localSpeaking,
      participants: participants,
    ),
  );

  Widget get _audioControls {
    if (showingLocalScreen) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Предпросмотр собственного экрана без звука.',
            style: TextStyle(color: GcColors.muted, fontSize: 12),
          ),
        ),
      );
    }
    if (!screenAudioAvailable) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'У демонстрации нет аудиодорожки.',
            style: TextStyle(color: GcColors.muted, fontSize: 12),
          ),
        ),
      );
    }
    if (screenAudioVolume == null) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Аудиодорожка есть; личная настройка громкости недоступна.',
            style: TextStyle(color: GcColors.muted, fontSize: 12),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Row(
        children: [
          SizedBox(
            width: 220,
            child: Text(
              deafened
                  ? 'Удалённый звук выключен.'
                  : 'Громкость аудиодорожки · $screenAudioVolume%',
              style: const TextStyle(color: GcColors.textSecondary),
            ),
          ),
          Expanded(
            child: Slider(
              value: screenAudioVolume!.toDouble(),
              min: 0,
              max: 200,
              divisions: 200,
              semanticFormatterCallback: (value) =>
                  '${value.round()} процентов',
              onChanged: deafened
                  ? null
                  : (value) => onScreenAudioVolumeChanged!(value.round()),
            ),
          ),
        ],
      ),
    );
  }

  Widget? get _streamRail {
    if (screens.isEmpty && !localScreenAvailable) return null;
    final choices = [
      if (localScreenAvailable)
        VoiceScreenChoice(
          identity: null,
          label: 'Ваш экран',
          selected: showingLocalScreen,
          isLocal: true,
          avatarIdentity: state.user?.accountId,
          avatarLabel: localName,
        ),
      for (final participant in screens)
        VoiceScreenChoice(
          identity: participant.identity,
          label: _participantName(participant),
          selected: participant.identity == selectedIdentity,
          accountId: _voiceParticipantAccountId(participant),
          avatarLabel: _participantName(participant),
          hasAudio: participant.audioTrackPublications.any(
            (publication) =>
                publication.source == TrackSource.screenShareAudio &&
                publication.track != null,
          ),
        ),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Демонстрации в канале',
            style: TextStyle(
              color: GcColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          VoiceScreenSelectionRail(
            choices: choices,
            onSelected: onScreenSelected,
          ),
        ],
      ),
    );
  }
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
    required this.state,
    required this.localName,
    required this.localAvatarUrl,
    required this.localMuted,
    required this.localSpeaking,
    required this.participants,
  });

  final AppState state;
  final String localName;
  final String? localAvatarUrl;
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
                state: state,
                name: localName,
                avatarUrl: localAvatarUrl,
                muted: localMuted,
                speaking: localSpeaking,
                microphoneUnavailable: state.microphoneUnavailable,
                deafened: state.deafened,
              ),
              for (final participant in participants)
                _VoiceStripPerson(
                  state: state,
                  name: _participantName(participant),
                  avatarUrl: _participantMember(state, participant)?.avatarUrl,
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
    required this.state,
    required this.name,
    required this.avatarUrl,
    required this.muted,
    required this.speaking,
    this.microphoneUnavailable = false,
    this.deafened = false,
  });

  final AppState state;
  final String name;
  final String? avatarUrl;
  final bool muted;
  final bool speaking;
  final bool microphoneUnavailable;
  final bool deafened;

  @override
  Widget build(BuildContext context) {
    final presentation = VoiceParticipantPresentation.resolve(
      muted: muted,
      microphoneUnavailable: microphoneUnavailable,
      deafened: deafened,
      speaking: speaking,
    );
    return Container(
      width: 148,
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: GcColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: presentation.isSpeaking ? GcColors.success : GcColors.border,
        ),
      ),
      child: Row(
        children: [
          AuthenticatedAvatar(
            state: state,
            name: name,
            avatarUrl: avatarUrl,
            radius: 15,
            borderColor: presentation.isSpeaking ? GcColors.success : null,
            borderWidth: presentation.isSpeaking ? 2 : 0,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          Tooltip(
            message: presentation.label,
            child: Icon(
              deafened
                  ? Icons.headset_off
                  : muted || microphoneUnavailable
                  ? Icons.mic_off
                  : presentation.isSpeaking
                  ? Icons.graphic_eq
                  : Icons.mic,
              size: 15,
              color: deafened
                  ? GcColors.danger
                  : microphoneUnavailable
                  ? GcColors.warning
                  : muted
                  ? GcColors.danger
                  : GcColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _VoiceParticipantCard extends StatelessWidget {
  const _VoiceParticipantCard({
    required this.state,
    required this.name,
    required this.avatarUrl,
    required this.muted,
    required this.speaking,
    this.volume,
    this.onVolumeChanged,
    this.hasScreen = false,
    this.isLocal = false,
    this.onScreenTap,
    this.microphoneUnavailable = false,
    this.deafened = false,
  });
  final AppState state;
  final String name;
  final String? avatarUrl;
  final bool muted;
  final bool speaking;
  final int? volume;
  final ValueChanged<int>? onVolumeChanged;
  final bool hasScreen;
  final bool isLocal;
  final VoidCallback? onScreenTap;
  final bool microphoneUnavailable;
  final bool deafened;

  @override
  Widget build(BuildContext context) {
    final presentation = VoiceParticipantPresentation.resolve(
      muted: muted,
      microphoneUnavailable: microphoneUnavailable,
      deafened: deafened,
      speaking: speaking,
    );
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: GcColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: presentation.isSpeaking ? GcColors.success : GcColors.border,
          width: presentation.isSpeaking ? 2 : 1,
        ),
      ),
      child: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AuthenticatedAvatar(
                  state: state,
                  name: name,
                  avatarUrl: avatarUrl,
                  radius: 31,
                  borderColor: presentation.isSpeaking
                      ? GcColors.success
                      : const Color(0x44365ACA),
                  borderWidth: presentation.isSpeaking ? 3 : 1,
                ),
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
                      deafened
                          ? Icons.headset_off
                          : muted || microphoneUnavailable
                          ? Icons.mic_off
                          : presentation.isSpeaking
                          ? Icons.graphic_eq
                          : Icons.mic,
                      size: 16,
                      color: deafened
                          ? GcColors.danger
                          : microphoneUnavailable
                          ? GcColors.warning
                          : muted
                          ? GcColors.danger
                          : GcColors.textSecondary,
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  presentation.label,
                  style: TextStyle(
                    color: presentation.isSpeaking
                        ? GcColors.success
                        : GcColors.muted,
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
          ),
          if (volume != null && onVolumeChanged != null)
            Positioned(
              top: -12,
              right: -12,
              child: _VoiceVolumeMenu(
                name: name,
                volume: volume!,
                onChanged: onVolumeChanged!,
              ),
            ),
        ],
      ),
    );
  }
}

class _VoiceVolumeMenu extends StatefulWidget {
  const _VoiceVolumeMenu({
    required this.name,
    required this.volume,
    required this.onChanged,
  });

  final String name;
  final int volume;
  final ValueChanged<int> onChanged;

  @override
  State<_VoiceVolumeMenu> createState() => _VoiceVolumeMenuState();
}

class _VoiceVolumeMenuState extends State<_VoiceVolumeMenu> {
  late int _volume = widget.volume;

  @override
  void didUpdateWidget(covariant _VoiceVolumeMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.volume != widget.volume) _volume = widget.volume;
  }

  @override
  Widget build(BuildContext context) => MenuAnchor(
    menuChildren: [
      SizedBox(
        width: 240,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Громкость · $_volume%'),
              Slider(
                value: _volume.toDouble(),
                min: 0,
                max: 200,
                divisions: 200,
                semanticFormatterCallback: (value) =>
                    '${value.round()} процентов',
                onChanged: (value) {
                  setState(() => _volume = value.round());
                  widget.onChanged(_volume);
                },
              ),
            ],
          ),
        ),
      ),
    ],
    builder: (context, controller, child) => IconButton(
      tooltip: 'Настройки громкости ${widget.name}',
      onPressed: controller.isOpen ? controller.close : controller.open,
      icon: const Icon(Icons.more_horiz, size: 20),
    ),
  );
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({this.color = GcColors.success});
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 7,
    height: 7,
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      boxShadow: [
        BoxShadow(color: color.withValues(alpha: 0.55), blurRadius: 7),
      ],
    ),
  );
}

class _ProfilePanelToolbar extends StatelessWidget {
  const _ProfilePanelToolbar({this.onToggleNavigation, this.onBack});

  final VoidCallback? onToggleNavigation;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.sizeOf(context).width <= 720 ? 16.0 : 24.0;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: inset),
      child: SizedBox(
        height: GcLayout.control,
        child: Row(
          children: [
            if (onBack != null)
              IconButton(
                tooltip: 'Назад',
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back),
              ),
            const Spacer(),
            if (onToggleNavigation != null)
              IconButton(
                tooltip: 'Открыть навигацию',
                onPressed: onToggleNavigation,
                icon: const Icon(Icons.menu),
              ),
          ],
        ),
      ),
    );
  }
}

class _AudioSettingsScreen extends StatelessWidget {
  const _AudioSettingsScreen({
    required this.state,
    required this.onBack,
    required this.onCapturePttKey,
    required this.capturingPttKey,
  });
  final AppState state;
  final VoidCallback onBack;
  final VoidCallback? onCapturePttKey;
  final bool capturingPttKey;

  @override
  Widget build(BuildContext context) {
    final compact =
        MediaQuery.sizeOf(context).width < GcLayout.mobileBreakpoint;
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) onBack();
      },
      child: AnimatedBuilder(
        animation: state,
        builder: (context, _) => Column(
          children: [
            _Header(
              icon: Icons.tune,
              title: 'Настройки аудио',
              subtitle: 'Устройства и обработка микрофона',
              onBack: compact ? onBack : null,
              trailing: IconButton(
                tooltip: 'Обновить список устройств',
                onPressed: state.audioDevicesLoading
                    ? null
                    : state.refreshAudioDevices,
                icon: state.audioDevicesLoading
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  _AudioDeviceDropdown(
                    label: 'Микрофон',
                    icon: Icons.mic_none,
                    devices: state.audioInputDevices,
                    selectedId: state.selectedAudioInputId,
                    emptyLabel: state.audioDevicesLoading
                        ? 'Ищем устройства…'
                        : state.audioDeviceScanFailed
                        ? 'Список недоступен'
                        : 'Микрофоны не найдены',
                    onChanged: state.selectAudioInput,
                  ),
                  const SizedBox(height: 16),
                  _AudioDeviceDropdown(
                    label: 'Динамик',
                    icon: Icons.volume_up_outlined,
                    devices: state.audioOutputDevices,
                    selectedId: state.selectedAudioOutputId,
                    emptyLabel: state.audioDevicesLoading
                        ? 'Ищем устройства…'
                        : state.audioDeviceScanFailed
                        ? 'Список недоступен'
                        : 'Динамики не найдены',
                    onChanged: state.selectAudioOutput,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Активация микрофона',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<AudioActivationMode>(
                    initialValue: state.audioActivationMode,
                    decoration: const InputDecoration(
                      labelText: 'Режим',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: AudioActivationMode.vad,
                        child: Text('Голосовая активность'),
                      ),
                      DropdownMenuItem(
                        value: AudioActivationMode.ptt,
                        child: Text('Push-to-talk'),
                      ),
                    ],
                    onChanged: (mode) {
                      if (mode != null) {
                        unawaited(state.setAudioActivationMode(mode));
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: onCapturePttKey,
                    icon: Icon(
                      capturingPttKey
                          ? Icons.keyboard
                          : Icons.keyboard_alt_outlined,
                    ),
                    label: Text(
                      capturingPttKey
                          ? 'Нажмите клавишу… · Esc — отмена'
                          : state.pushToTalkKeyLabel == null
                          ? 'Назначить PTT-клавишу'
                          : 'Клавиша PTT · ${state.pushToTalkKeyLabel}',
                    ),
                  ),
                  if (state.audioActivationMode == AudioActivationMode.ptt)
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text(
                        'Удерживайте назначенную клавишу, чтобы говорить. При потере фокуса микрофон выключается.',
                        style: TextStyle(color: GcColors.muted, fontSize: 12),
                      ),
                    ),
                  if (state.audioActivationError != null) ...[
                    const SizedBox(height: 8),
                    _ErrorBanner(message: state.audioActivationError!),
                  ],
                  const SizedBox(height: 24),
                  Text(
                    'Обработка микрофона',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Параметры передаются LiveKit. Нативный SDK не сообщает, '
                    'какие эффекты фактически применены устройством.',
                    style: TextStyle(color: GcColors.muted, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Автоматическая регулировка усиления'),
                    value: state.audioProcessing.autoGainControl,
                    onChanged: (value) => state.setAudioProcessing(
                      state.audioProcessing.copyWith(autoGainControl: value),
                    ),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Подавление эха'),
                    value: state.audioProcessing.echoCancellation,
                    onChanged: (value) => state.setAudioProcessing(
                      state.audioProcessing.copyWith(echoCancellation: value),
                    ),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Подавление шума'),
                    value: state.audioProcessing.noiseSuppression,
                    onChanged: (value) => state.setAudioProcessing(
                      state.audioProcessing.copyWith(noiseSuppression: value),
                    ),
                  ),
                  if (state.audioSettingsError != null) ...[
                    const SizedBox(height: 12),
                    _ErrorBanner(message: state.audioSettingsError!),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AudioDeviceDropdown extends StatelessWidget {
  const _AudioDeviceDropdown({
    required this.label,
    required this.icon,
    required this.devices,
    required this.selectedId,
    required this.emptyLabel,
    required this.onChanged,
  });

  final String label;
  final IconData icon;
  final List<MediaDevice> devices;
  final String? selectedId;
  final String emptyLabel;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = devices.any((device) => device.deviceId == selectedId)
        ? selectedId!
        : devices.isEmpty
        ? '__none__'
        : devices.first.deviceId;
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: selected,
          items: [
            if (devices.isEmpty)
              DropdownMenuItem(
                value: '__none__',
                enabled: false,
                child: Text(emptyLabel),
              ),
            for (var index = 0; index < devices.length; index++)
              DropdownMenuItem(
                value: devices[index].deviceId,
                child: Text(
                  devices[index].deviceId == 'default'
                      ? 'Системный выбор · $label'
                      : devices[index].label.trim().isEmpty
                      ? '$label ${index + 1}'
                      : devices[index].label,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: devices.isEmpty
              ? null
              : (value) {
                  if (value != null) onChanged(value);
                },
        ),
      ),
    );
  }
}

class _VoiceDock extends StatelessWidget {
  const _VoiceDock({required this.state});
  final AppState state;

  String get _status => switch (state.voicePhase) {
    VoicePhase.joining => 'Подключаемся к голосовому каналу',
    VoicePhase.reconnecting => 'Восстанавливаем голосовое соединение',
    VoicePhase.leaving => 'Завершаем голосовое подключение',
    _ => 'В голосовом канале',
  };

  String get _hint => switch (state.voicePhase) {
    VoicePhase.joining => 'Соединяемся с голосовой комнатой.',
    VoicePhase.reconnecting => 'Ручной выход отменит ожидание.',
    VoicePhase.leaving => 'Ожидаем завершения голосовой сессии.',
    _ when state.deafened => 'Удалённый звук и микрофон выключены. Показ экрана этой кнопкой не отключается.',
    _ when state.microphoneUnavailable =>
      'Микрофон недоступен: вы остаётесь слушателем.',
    _ => 'Вы можете открыть другой канал: голос останется активным.',
  };

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
        Semantics(
          container: true,
          liveRegion: true,
          label: '$_status · ${state.voiceChannel!.name}',
          child: Row(
            children: [
              _StatusDot(
                color: state.voicePhase == VoicePhase.reconnecting
                    ? GcColors.warning
                    : GcColors.success,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _status,
                      style: TextStyle(
                        color: state.voicePhase == VoicePhase.reconnecting
                            ? GcColors.warning
                            : GcColors.success,
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
        ),
        const SizedBox(height: 4),
        Text(
          _hint,
          style: const TextStyle(
            color: GcColors.muted,
            fontSize: 11,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 11),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _VoiceDockButton(
              tooltip: state.microphoneUnavailable
                  ? 'Микрофон недоступен · повторить включение'
                  : state.audioActivationMode == AudioActivationMode.ptt
                  ? 'Микрофон управляется push-to-talk'
                  : state.microphoneMuted
                  ? 'Включить микрофон'
                  : 'Выключить микрофон',
              icon: state.microphoneMuted ? Icons.mic_off : Icons.mic,
              danger: state.microphoneMuted,
              enabled:
                  state.audioActivationMode != AudioActivationMode.ptt &&
                  !state.deafened,
              onTap: state.toggleMicrophone,
            ),
            _VoiceDockButton(
              tooltip: state.deafened
                  ? 'Включить удалённый звук'
                  : 'Выключить удалённый звук',
              icon: state.deafened ? Icons.headset_off : Icons.headphones,
              danger: state.deafened,
              enabled:
                  !state.deafenChanging &&
                  state.voicePhase != VoicePhase.leaving,
              onTap: state.toggleDeafen,
            ),
            _VoiceDockButton(
              tooltip: state.voicePhase == VoicePhase.leaving
                  ? 'Выходим…'
                  : 'Выйти из голосового канала',
              icon: Icons.call_end,
              danger: true,
              enabled: state.voicePhase != VoicePhase.leaving,
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
    this.enabled = true,
  });
  final IconData icon;
  final String tooltip;
  final bool danger;
  final VoidCallback onTap;
  final bool enabled;
  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Material(
      color: danger ? const Color(0x33422830) : GcColors.raised,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: enabled ? onTap : null,
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
  const _UserFooter({required this.state, this.onNavigate});
  final AppState state;
  final VoidCallback? onNavigate;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 68,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () {
                state.toggleWorkspacePanel(WorkspacePanel.profile);
                onNavigate?.call();
              },
              borderRadius: BorderRadius.circular(6),
              child: Row(
                children: [
                  AuthenticatedAvatar(
                    state: state,
                    name: state.profile?.displayName ?? 'Вы',
                    avatarUrl: state.profile?.avatarUrl,
                    radius: 18,
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
                onNavigate?.call();
              }
              if (value == 'audio') {
                state.toggleWorkspacePanel(WorkspacePanel.audio);
                onNavigate?.call();
              }
              if (value == 'admin') {
                state.toggleWorkspacePanel(WorkspacePanel.admin);
                onNavigate?.call();
              }
            },
            itemBuilder: (_) => [
              if (state.user?.isAdmin == true)
                const PopupMenuItem(
                  value: 'admin',
                  child: Row(
                    children: [
                      Icon(Icons.admin_panel_settings_outlined, size: 18),
                      SizedBox(width: 10),
                      Text('Администрирование'),
                    ],
                  ),
                ),
              PopupMenuItem(
                value: 'audio',
                child: Row(
                  children: [
                    Icon(Icons.tune, size: 18),
                    SizedBox(width: 10),
                    Text('Настройки аудио'),
                  ],
                ),
              ),
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

class _MembersPanel extends StatefulWidget {
  const _MembersPanel({required this.state, this.onClose});
  final AppState state;
  final VoidCallback? onClose;

  @override
  State<_MembersPanel> createState() => _MembersPanelState();
}

class _MembersPanelState extends State<_MembersPanel> {
  AppState get state => widget.state;
  VoidCallback? get onClose => widget.onClose;

  final OverlayPortalController _profilePortal = OverlayPortalController();
  final LayerLink _profileLink = LayerLink();
  final FocusNode _profileTriggerFocus = FocusNode(
    debugLabel: 'member-profile-trigger',
  );
  String? _profileMemberId;
  String? _profileTriggerMemberId;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleHardwareKey);
  }

  bool _handleHardwareKey(KeyEvent event) {
    if (_profileMemberId != null &&
        event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape) {
      _closeMemberProfile();
      return true;
    }
    return false;
  }

  void _showMemberProfile(GuildMember member) {
    _profileTriggerMemberId = member.id;
    _profileTriggerFocus.requestFocus();
    setState(() => _profileMemberId = member.id);
    _profilePortal.show();
  }

  void _closeMemberProfile() {
    _profilePortal.hide();
    setState(() => _profileMemberId = null);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _profileTriggerFocus.canRequestFocus) {
        _profileTriggerFocus.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleHardwareKey);
    _profileTriggerFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: state,
    builder: (context, _) => _buildPanel(context),
  );

  Widget _buildPanel(BuildContext context) {
    final groups = [
      (
        title: 'В сети',
        members: state.members
            .where(
              (member) => state.memberPresence(member) == MemberPresence.online,
            )
            .toList(),
      ),
      (
        title: 'Не в сети',
        members: state.members
            .where(
              (member) =>
                  state.memberPresence(member) == MemberPresence.offline,
            )
            .toList(),
      ),
      (
        title: 'Статус неизвестен',
        members: state.members
            .where(
              (member) =>
                  state.memberPresence(member) == MemberPresence.unknown,
            )
            .toList(),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) => OverlayPortal(
        controller: _profilePortal,
        overlayChildBuilder: (context) {
          final memberId = _profileMemberId;
          if (memberId == null) return const SizedBox.shrink();
          final popoverWidth = (constraints.maxWidth - GcSpacing.x8)
              .clamp(0.0, 288.0)
              .toDouble();
          return Focus(
            onKeyEvent: (node, event) {
              if (event is KeyDownEvent &&
                  event.logicalKey == LogicalKeyboardKey.escape) {
                _closeMemberProfile();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: CompositedTransformFollower(
              link: _profileLink,
              showWhenUnlinked: false,
              targetAnchor: Alignment.topRight,
              followerAnchor: Alignment.topRight,
              offset: const Offset(8, 0),
              child: UnconstrainedBox(
                alignment: Alignment.topRight,
                child: _MemberProfilePopover(
                  key: ValueKey(memberId),
                  state: state,
                  memberId: memberId,
                  width: popoverWidth,
                  onClose: _closeMemberProfile,
                  onOpenDirectMessage: (member) async {
                    _closeMemberProfile();
                    await state.createDirectConversation(
                      DirectCandidate(
                        id: member.id,
                        displayName: member.displayName,
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
        child: ColoredBox(
          color: GcColors.sidebar,
          child: Padding(
            key: const ValueKey('members-panel'),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'УЧАСТНИКИ',
                        style: TextStyle(
                          color: GcColors.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: .7,
                        ),
                      ),
                    ),
                    if (onClose != null)
                      IconButton(
                        tooltip: 'Закрыть участников',
                        onPressed: onClose,
                        icon: const Icon(Icons.close),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: state.refreshMembers,
                    child: ListView(
                      children: [
                        if (state.membersError != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Semantics(
                                  liveRegion: true,
                                  child: Text(
                                    state.membersError!,
                                    style: const TextStyle(
                                      color: GcColors.danger,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: state.membersLoading
                                      ? null
                                      : state.refreshMembers,
                                  child: Text(
                                    state.membersLoading
                                        ? 'Загружаем…'
                                        : 'Повторить',
                                  ),
                                ),
                              ],
                            ),
                          )
                        else if (state.membersLoading && state.members.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Text(
                              'Загружаем участников…',
                              style: TextStyle(color: GcColors.muted),
                            ),
                          )
                        else if (state.members.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Text(
                              'В гильдии пока нет участников.',
                              style: TextStyle(color: GcColors.muted),
                            ),
                          ),
                        for (final group in groups)
                          if (group.members.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.only(
                                top: 20,
                                bottom: 8,
                              ),
                              child: Semantics(
                                header: true,
                                child: Text(
                                  '${group.title} — ${group.members.length}',
                                  style: const TextStyle(
                                    color: GcColors.muted,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                            for (final member in group.members)
                              _memberRow(context, member),
                          ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _memberRow(BuildContext context, GuildMember member) {
    final tile = _memberTile(context, member, state.memberPresence(member));
    if (_profileTriggerMemberId != member.id) return tile;
    return CompositedTransformTarget(
      link: _profileLink,
      child: Focus(focusNode: _profileTriggerFocus, child: tile),
    );
  }

  Widget _memberTile(
    BuildContext context,
    GuildMember member,
    MemberPresence memberPresence,
  ) {
    final presence = switch (memberPresence) {
      MemberPresence.online => ('В сети', GcColors.success),
      MemberPresence.offline => ('Не в сети', GcColors.muted),
      MemberPresence.unknown => ('Статус неизвестен', GcColors.warning),
    };
    return Material(
      color: GcColors.sidebar,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        onTap: () => _showMemberProfile(member),
        leading: Stack(
          children: [
            AuthenticatedAvatar(
              state: state,
              name: member.displayName,
              avatarUrl: member.avatarUrl,
              radius: 20,
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
                  border: Border.all(color: GcColors.sidebar, width: 2),
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
          style: const TextStyle(color: GcColors.muted, fontSize: 11),
        ),
      ),
    );
  }
}

class _MemberProfilePopover extends StatefulWidget {
  const _MemberProfilePopover({
    super.key,
    required this.state,
    required this.memberId,
    required this.width,
    required this.onClose,
    required this.onOpenDirectMessage,
  });

  final AppState state;
  final String memberId;
  final double width;
  final VoidCallback onClose;
  final ValueChanged<GuildMember> onOpenDirectMessage;

  @override
  State<_MemberProfilePopover> createState() => _MemberProfilePopoverState();
}

class _MemberProfilePopoverState extends State<_MemberProfilePopover> {
  GuildMember? _member;
  String? _error;
  String? _status;
  bool _loading = true;
  bool _kicking = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final member = await widget.state.api.memberProfile(widget.memberId);
      if (mounted) setState(() => _member = member);
    } catch (cause) {
      if (mounted) setState(() => _error = cause.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _kick(RemoteParticipant participant) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Отключить от голоса?'),
        content: const Text('Отключить участника от голосового канала?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Отключить'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _kicking = true;
      _error = null;
      _status = null;
    });
    try {
      final revoked = await widget.state.api.kickAdminVoiceParticipant(
        widget.memberId,
      );
      if (mounted) {
        setState(
          () => _status = revoked > 0
              ? 'Подключение отозвано.'
              : 'Активное голосовое подключение не найдено.',
        );
      }
    } catch (cause) {
      if (mounted) setState(() => _error = cause.toString());
    } finally {
      if (mounted) setState(() => _kicking = false);
    }
  }

  Widget _buildPopover(BuildContext context) {
    final participant = widget.state.voiceParticipantForAccount(
      widget.memberId,
    );
    final canMessage = _member?.id != widget.state.user?.accountId;
    final canKick =
        canMessage && participant != null && widget.state.user?.isAdmin == true;
    return Material(
      key: const ValueKey('member-profile-popover'),
      color: GcColors.raised,
      elevation: 8,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: GcColors.border),
        borderRadius: BorderRadius.circular(GcRadii.md),
      ),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: widget.width,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Профиль участника',
                      style: TextStyle(color: GcColors.muted, fontSize: 12),
                    ),
                  ),
                  IconButton(
                    autofocus: true,
                    tooltip: 'Закрыть профиль',
                    visualDensity: VisualDensity.compact,
                    onPressed: widget.onClose,
                    icon: const Icon(Icons.close, size: 18),
                  ),
                ],
              ),
              const SizedBox(height: GcSpacing.x4),
              if (_loading)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Semantics(
                    liveRegion: true,
                    child: Text('Загружаем профиль…'),
                  ),
                )
              else if (_error != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        _error!,
                        style: const TextStyle(color: GcColors.danger),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Повторить'),
                    ),
                  ],
                )
              else if (_member case final member?) ...[
                Row(
                  children: [
                    AuthenticatedAvatar(
                      state: widget.state,
                      name: member.displayName,
                      avatarUrl: member.avatarUrl,
                      radius: 32,
                      backgroundColor: GcColors.avatarViolet,
                      fallbackFontSize: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            member.displayName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: GcColors.text,
                              fontSize: 20,
                              height: 28 / 20,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '@${member.login}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: GcColors.textSecondary,
                              fontSize: 14,
                              height: 20 / 14,
                            ),
                          ),
                          Text(
                            member.role == 'ADMINISTRATOR'
                                ? 'Администратор'
                                : 'Участник',
                            style: const TextStyle(
                              color: GcColors.muted,
                              fontSize: 12,
                              height: 16 / 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (canMessage || canKick) ...[
                  const SizedBox(height: GcSpacing.x4),
                  if (canMessage)
                    OutlinedButton(
                      onPressed: member.id == widget.state.user?.accountId
                          ? null
                          : () => widget.onOpenDirectMessage(member),
                      style: _memberProfileActionStyle,
                      child: const Text('Сообщение'),
                    ),
                  if (canKick) ...[
                    const SizedBox(height: GcSpacing.x2),
                    OutlinedButton.icon(
                      onPressed: _kicking ? null : () => _kick(participant),
                      icon: const Icon(Icons.call_end, size: 18),
                      label: Text(
                        _kicking ? 'Отключаем…' : 'Отключить от голоса',
                      ),
                      style: _memberProfileActionStyle,
                    ),
                  ],
                ],
                if (participant != null) ...[
                  const SizedBox(height: GcSpacing.x4),
                  const Text(
                    'Громкость участника',
                    style: TextStyle(
                      color: GcColors.textSecondary,
                      fontSize: 13,
                      height: 18 / 13,
                    ),
                  ),
                  const SizedBox(height: GcSpacing.x2),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: Text(
                      '${widget.state.participantVolume(participant) ?? 100}%',
                      style: const TextStyle(
                        color: GcColors.textSecondary,
                        fontSize: 13,
                        height: 18 / 13,
                      ),
                    ),
                  ),
                  const SizedBox(height: GcSpacing.x2),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: GcColors.accent,
                      thumbColor: GcColors.accent,
                      inactiveTrackColor: GcColors.control.withValues(
                        alpha: 0.55,
                      ),
                    ),
                    child: Slider(
                      value:
                          (widget.state.participantVolume(participant) ?? 100)
                              .toDouble(),
                      min: 0,
                      max: 200,
                      divisions: 200,
                      semanticFormatterCallback: (value) =>
                          '${value.round()} процентов',
                      onChanged: (value) => unawaited(
                        widget.state.setParticipantVolume(
                          participant,
                          value.round(),
                        ),
                      ),
                    ),
                  ),
                ],
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: GcColors.danger),
                    ),
                  ),
                if (_status != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        _status!,
                        style: const TextStyle(color: GcColors.success),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.state,
    builder: (context, _) => _buildPopover(context),
  );
}

final _memberProfileActionStyle = OutlinedButton.styleFrom(
  minimumSize: const Size(0, GcLayout.control),
  visualDensity: VisualDensity.compact,
  padding: const EdgeInsets.symmetric(horizontal: GcSpacing.x3),
  foregroundColor: GcColors.text,
  backgroundColor: GcColors.surface,
  side: const BorderSide(color: GcColors.control),
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(GcRadii.sm),
  ),
  textStyle: const TextStyle(fontSize: 14, height: 20 / 14),
);

Future<void> _editMessageDialog(
  BuildContext context,
  String initialValue,
  int initialRevision,
  List<String> initialMentionIds,
  List<(String, String)> mentionOptions,
  String selfId,
  Future<MessageEditOutcome> Function(String, int, List<String>) onSave,
  Future<({int revision, bool deleted})?> Function() onRefresh,
) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _MessageEditDialog(
    initialValue: initialValue,
    initialRevision: initialRevision,
    initialMentionIds: initialMentionIds,
    mentionOptions: mentionOptions,
    selfId: selfId,
    onSave: onSave,
    onRefresh: onRefresh,
  ),
);

class _MessageEditDialog extends StatefulWidget {
  const _MessageEditDialog({
    required this.initialValue,
    required this.initialRevision,
    required this.initialMentionIds,
    required this.mentionOptions,
    required this.selfId,
    required this.onSave,
    required this.onRefresh,
  });

  final String initialValue;
  final int initialRevision;
  final List<String> initialMentionIds;
  final List<(String, String)> mentionOptions;
  final String selfId;
  final Future<MessageEditOutcome> Function(String, int, List<String>) onSave;
  final Future<({int revision, bool deleted})?> Function() onRefresh;

  @override
  State<_MessageEditDialog> createState() => _MessageEditDialogState();
}

class _MessageEditDialogState extends State<_MessageEditDialog> {
  late final TextEditingController _controller;
  late int _revision;
  late final Set<String> _mentionIds;
  bool _pending = false;
  bool _needsRefresh = false;
  String? _error;
  String? _notice;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _revision = widget.initialRevision;
    _mentionIds = widget.initialMentionIds.toSet();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_pending || _needsRefresh) return;
    final body = _controller.text;
    if (body.trim().isEmpty || body.trim().runes.length > 8000) {
      setState(() => _error = 'Сообщение должно содержать до 8000 символов.');
      return;
    }
    setState(() {
      _pending = true;
      _error = null;
      _notice = null;
    });
    MessageEditOutcome outcome;
    try {
      outcome = await widget.onSave(body, _revision, _mentionIds.toList());
    } catch (_) {
      outcome = (
        kind: MessageEditStatus.error,
        message: 'Не удалось сохранить сообщение. Повторите попытку.',
      );
    }
    if (!mounted) return;
    if (outcome.kind == MessageEditStatus.saved) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _pending = false;
      _needsRefresh = outcome.kind == MessageEditStatus.conflict;
      _error = outcome.message ?? 'Не удалось сохранить сообщение.';
    });
  }

  Future<void> _refresh() async {
    if (_pending || !_needsRefresh) return;
    setState(() {
      _pending = true;
      _error = null;
    });
    ({int revision, bool deleted})? latest;
    try {
      latest = await widget.onRefresh();
    } catch (_) {
      latest = null;
    }
    if (!mounted) return;
    setState(() {
      _pending = false;
      if (latest?.deleted == true) {
        _error = 'Сообщение удалено. Ваш черновик сохранён для копирования.';
      } else if (latest != null && latest.revision > _revision) {
        _revision = latest.revision;
        _needsRefresh = false;
        _notice = 'Версия обновлена. Проверьте свой текст перед повторным сохранением.';
      } else {
        _error =
            'Не удалось получить новую версию сообщения. Повторите обновление.';
      }
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Изменить сообщение'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            enabled: !_pending,
            maxLength: 8000,
            minLines: 2,
            maxLines: 8,
            decoration: const InputDecoration(
              labelText: 'Изменённый текст сообщения',
            ),
          ),
          _MentionPicker(
            options: widget.mentionOptions,
            selfId: widget.selfId,
            selectedIds: _mentionIds,
            disabled: _pending,
            onChanged: (ids) => setState(() {
              _mentionIds
                ..clear()
                ..addAll(ids);
            }),
          ),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: GcColors.danger)),
          if (_notice != null)
            Text(_notice!, style: const TextStyle(color: GcColors.muted)),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: _pending ? null : () => Navigator.pop(context),
        child: const Text('Отмена'),
      ),
      if (_needsRefresh)
        TextButton(
          onPressed: _pending ? null : _refresh,
          child: const Text('Обновить версию'),
        ),
      FilledButton(
        onPressed: _pending || _needsRefresh ? null : _save,
        child: Text(_pending ? 'Обрабатываем…' : 'Сохранить'),
      ),
    ],
  );
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
