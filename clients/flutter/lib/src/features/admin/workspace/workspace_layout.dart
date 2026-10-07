part of 'workspace.dart';

mixin _WorkspaceLayout on _AdminWorkspaceBase {
  Widget _buildWorkspace(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < GcLayout.mobileBreakpoint;
    return Material(
      color: GcColors.content,
      child: Column(
        children: [
          AdminWorkspaceHeader(
            compact: compact,
            titleFocus: _titleFocus,
            onToggleNavigation: widget.onToggleNavigation,
            onClose: () => unawaited(_closeWorkspace()),
          ),
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 880),
                child: SizedBox(
                  key: const ValueKey('admin-content-panel'),
                  width: double.infinity,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      compact ? 16 : 0,
                      compact ? 24 : 32,
                      compact ? 16 : 0,
                      0,
                    ),
                    child: Column(
                      children: [
                        _buildNavigation(context, width),
                        Expanded(child: _buildSelectedSection(context)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
