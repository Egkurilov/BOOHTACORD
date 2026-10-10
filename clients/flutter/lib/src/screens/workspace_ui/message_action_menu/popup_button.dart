import 'package:flutter/material.dart';

class WorkspaceMessageActionPopupButton extends StatefulWidget {
  const WorkspaceMessageActionPopupButton({
    super.key,
    required this.mobile,
    required this.items,
    required this.onSelected,
  });

  final bool mobile;
  final List<PopupMenuEntry<String>> items;
  final ValueChanged<String> onSelected;

  @override
  State<WorkspaceMessageActionPopupButton> createState() =>
      _WorkspaceMessageActionPopupButtonState();
}

class _WorkspaceMessageActionPopupButtonState
    extends State<WorkspaceMessageActionPopupButton> {
  late final _focusNode = FocusNode(debugLabel: 'message-actions-trigger');

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final targetSize = widget.mobile ? 48.0 : 40.0;
    return Focus(
      focusNode: _focusNode,
      child: PopupMenuButton<String>(
        tooltip: 'Действия с сообщением',
        onSelected: (action) {
          _focusNode.requestFocus();
          widget.onSelected(action);
        },
        itemBuilder: (_) => widget.items,
        style: ButtonStyle(
          tapTargetSize: widget.mobile
              ? MaterialTapTargetSize.padded
              : MaterialTapTargetSize.shrinkWrap,
        ),
        child: Semantics(
          label: 'Действия с сообщением',
          button: true,
          child: SizedBox.square(
            dimension: targetSize,
            child: const Icon(Icons.more_horiz, size: 18),
          ),
        ),
      ),
    );
  }
}
