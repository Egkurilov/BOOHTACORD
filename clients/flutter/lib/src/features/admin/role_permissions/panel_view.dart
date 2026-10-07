part of 'panel.dart';

extension _RolePermissionView on RolePermissionsPanelState {
  Widget _buildPanel(BuildContext context) => PopScope<Object?>(
    canPop: !hasPendingChanges || _allowPop,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop && hasPendingChanges) unawaited(_confirmRoutePop());
    },
    child: FocusTraversalGroup(
      key: const ValueKey('role-permissions-focus-order'),
      policy: WidgetOrderTraversalPolicy(),
      child: LayoutBuilder(builder: (context, constraints) {
        final inset = constraints.maxWidth >= 1024 ? 24.0 : 12.0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(inset, 4, inset, 8),
              child: _panelHeader(),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: inset),
              child: _roleTabs(),
            ),
            if (role == GuildRole.administrator) _administratorNote(inset),
            if (role == GuildRole.member) _deleteNotice(inset),
            if (role == GuildRole.member || hasPendingDraft) _dirtyNotice(inset),
            if (error != null || status != null) _feedback(inset),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(inset, 8, inset, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (loading && roles.isEmpty)
                      const Center(child: CircularProgressIndicator())
                    else
                      _permissionMatrix(
                        role == GuildRole.member
                            ? draft
                            : selected?.permissions ??
                                const <GuildPermission, bool>{},
                        constraints.maxWidth,
                      ),
                    if (conflictReview != null)
                      _conflictReviewView(constraints.maxWidth),
                  ],
                ),
              ),
            ),
            _actionBar(constraints.maxWidth),
          ],
        );
      }),
    ),
  );
}
