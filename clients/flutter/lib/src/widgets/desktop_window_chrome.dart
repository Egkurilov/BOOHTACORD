import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../theme.dart';
import '../features/guild/profile/desktop_title.dart';

abstract interface class DesktopWindowActions {
  Future<void> startDragging();
  Future<bool> isMaximized();
  Future<void> maximize();
  Future<void> restore();
  Future<void> minimize();
  Future<void> close();
}

class WindowManagerDesktopActions implements DesktopWindowActions {
  const WindowManagerDesktopActions();

  @override
  Future<void> close() => windowManager.close();

  @override
  Future<bool> isMaximized() => windowManager.isMaximized();

  @override
  Future<void> maximize() => windowManager.maximize();

  @override
  Future<void> minimize() => windowManager.minimize();

  @override
  Future<void> restore() => windowManager.unmaximize();

  @override
  Future<void> startDragging() => windowManager.startDragging();
}

class DesktopWindowChrome extends StatefulWidget {
  const DesktopWindowChrome({
    super.key,
    required this.child,
    this.platform,
    this.actions,
    this.title = 'BOOHTACORD',
  });

  final Widget child;
  final String title;
  final TargetPlatform? platform;
  final DesktopWindowActions? actions;

  @override
  State<DesktopWindowChrome> createState() => _DesktopWindowChromeState();
}

class _DesktopWindowChromeState extends State<DesktopWindowChrome>
    with WindowListener {
  bool _maximized = false;

  TargetPlatform get _platform => widget.platform ?? defaultTargetPlatform;
  DesktopWindowActions get _actions =>
      widget.actions ?? const WindowManagerDesktopActions();
  bool get _isDesktop =>
      _platform == TargetPlatform.macOS || _platform == TargetPlatform.windows;
  bool get _isWindows => _platform == TargetPlatform.windows;

  @override
  void initState() {
    super.initState();
    if (_isDesktop && widget.actions == null) {
      windowManager.addListener(this);
    }
    if (_isDesktop && widget.actions == null) unawaited(windowManager.setTitle(widget.title).catchError((Object _) {}));
    if (_isWindows) unawaited(_refreshMaximized());
  }

  @override
  void didUpdateWidget(covariant DesktopWindowChrome oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isDesktop && widget.actions == null && oldWidget.title != widget.title) unawaited(windowManager.setTitle(widget.title).catchError((Object _) {}));
    if (oldWidget.platform != widget.platform ||
        oldWidget.actions != widget.actions) {
      final oldPlatform = oldWidget.platform ?? defaultTargetPlatform;
      final oldPlatformIsDesktop =
          oldPlatform == TargetPlatform.macOS ||
          oldPlatform == TargetPlatform.windows;
      if (oldPlatformIsDesktop && oldWidget.actions == null) {
        windowManager.removeListener(this);
      }
      if (_isDesktop && widget.actions == null) {
        windowManager.addListener(this);
      }
      if (_isWindows) unawaited(_refreshMaximized());
    }
  }

  @override
  void dispose() {
    if (_isDesktop && widget.actions == null) {
      windowManager.removeListener(this);
    }
    super.dispose();
  }

  Future<void> _refreshMaximized() async {
    final maximized = await _actions.isMaximized();
    if (mounted) setState(() => _maximized = maximized);
  }

  Future<void> _toggleMaximize() async {
    final maximized = await _actions.isMaximized();
    if (maximized) {
      await _actions.restore();
    } else {
      await _actions.maximize();
    }
    if (mounted) setState(() => _maximized = !maximized);
  }

  @override
  void onWindowMaximize() {
    if (mounted) setState(() => _maximized = true);
  }

  @override
  void onWindowUnmaximize() {
    if (mounted) setState(() => _maximized = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_isDesktop) return widget.child;

    final macOS = _platform == TargetPlatform.macOS;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          key: const ValueKey('desktop-window-titlebar'),
          height: 32,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: GcColors.sidebar,
              border: Border(bottom: BorderSide(color: GcColors.borderSubtle)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    key: const ValueKey('desktop-window-drag-region'),
                    behavior: HitTestBehavior.opaque,
                    onPanStart: (_) => unawaited(_actions.startDragging()),
                    onDoubleTap: () => unawaited(_toggleMaximize()),
                    child: SizedBox.expand(
                      child: Padding(
                        padding: EdgeInsets.only(left: macOS ? 78 : 12),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: DesktopGuildTitle(widget.title),
                        ),
                      ),
                    ),
                  ),
                ),
                if (_isWindows) ...[
                  _WindowControlButton(
                    key: const ValueKey('desktop-window-minimize'),
                    tooltip: 'Свернуть',
                    icon: Icons.remove,
                    onPressed: _actions.minimize,
                  ),
                  _WindowControlButton(
                    key: const ValueKey('desktop-window-maximize'),
                    tooltip: _maximized ? 'Восстановить' : 'Развернуть',
                    icon: _maximized
                        ? Icons.filter_none_rounded
                        : Icons.crop_square_rounded,
                    onPressed: _toggleMaximize,
                  ),
                  _WindowControlButton(
                    key: const ValueKey('desktop-window-close'),
                    tooltip: 'Закрыть',
                    icon: Icons.close,
                    closeButton: true,
                    onPressed: _actions.close,
                  ),
                ],
              ],
            ),
          ),
        ),
        Expanded(child: widget.child),
      ],
    );
  }
}


class _WindowControlButton extends StatelessWidget {
  const _WindowControlButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.closeButton = false,
  });

  final String tooltip;
  final IconData icon;
  final Future<void> Function() onPressed;
  final bool closeButton;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 46,
    height: 32,
    child: Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => unawaited(onPressed()),
          mouseCursor: SystemMouseCursors.click,
          hoverColor: closeButton
              ? GcColors.danger
              : GcColors.text.withValues(alpha: .10),
          highlightColor: closeButton
              ? GcColors.danger.withValues(alpha: .85)
              : GcColors.text.withValues(alpha: .06),
          child: Center(
            child: Icon(
              icon,
              size: 15,
              color: closeButton ? GcColors.textSecondary : GcColors.muted,
            ),
          ),
        ),
      ),
    ),
  );
}
