import 'package:flutter/material.dart';

import '../../../theme.dart';

class AdminWorkspaceHeader extends StatelessWidget {
  const AdminWorkspaceHeader({
    required this.compact,
    required this.titleFocus,
    required this.onToggleNavigation,
    required this.onClose,
  });

  final bool compact;
  final FocusNode titleFocus;
  final VoidCallback? onToggleNavigation;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 44.0 : 36.0;
    final constraints = BoxConstraints.tightFor(width: size, height: size);
    return SizedBox(
      key: const ValueKey('admin-workspace-header'),
      height: compact ? 56 : 64,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: GcColors.borderSubtle)),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 24),
          child: Row(
            children: [
              if (compact && onToggleNavigation != null) ...[
                IconButton(
                  key: const ValueKey('admin-workspace-nav-toggle'),
                  tooltip: 'Открыть навигацию',
                  constraints: constraints,
                  padding: EdgeInsets.zero,
                  style: IconButton.styleFrom(
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    fixedSize: Size.square(size),
                    padding: EdgeInsets.zero,
                  ),
                  visualDensity: VisualDensity.compact,
                  onPressed: onToggleNavigation,
                  icon: const Icon(Icons.menu),
                ),
                const SizedBox(width: 8),
              ],
              const Icon(Icons.admin_panel_settings_outlined,
                  color: GcColors.muted, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Focus(
                  key: const ValueKey('admin-screen-title-focus'),
                  focusNode: titleFocus,
                  child: Semantics(
                    key: const ValueKey('admin-screen-title'),
                    header: true,
                    child: const Text(
                      'Администрирование',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
              IconButton(
                key: const ValueKey('admin-workspace-close'),
                tooltip: 'Закрыть администрирование',
                constraints: constraints,
                padding: EdgeInsets.zero,
                style: IconButton.styleFrom(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  fixedSize: Size.square(size),
                  padding: EdgeInsets.zero,
                ),
                visualDensity: VisualDensity.compact,
                onPressed: onClose,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
