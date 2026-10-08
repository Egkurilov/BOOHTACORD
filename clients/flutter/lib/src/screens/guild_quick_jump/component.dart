import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../features/workspace/quick_jump/state/controller.dart';
import 'content.dart';

class GuildQuickJumpPanel extends StatefulWidget {
  const GuildQuickJumpPanel({super.key, required this.createOwner});
  final QuickJumpController Function() createOwner;
  @override
  State<GuildQuickJumpPanel> createState() => GuildQuickJumpState();
}

class GuildQuickJumpState extends State<GuildQuickJumpPanel> {
  late final QuickJumpController owner;
  final query = TextEditingController();
  final focus = FocusNode();
  int selected = 0;
  @override
  void initState() {
    super.initState();
    owner = widget.createOwner()..addListener(changed);
    unawaited(owner.load());
  }

  void changed() {
    if (mounted) setState(() {});
  }

  void edit(String text) {
    selected = 0;
    owner.setQuery(text);
  }

  KeyEventResult keyEvent(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent ||
        owner.entries.isEmpty ||
        (query.value.composing.isValid && !query.value.composing.isCollapsed)) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.arrowUp) {
      setState(
        () => selected =
            (selected + (key == LogicalKeyboardKey.arrowDown ? 1 : -1)) %
            owner.entries.length,
      );
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      unawaited(
        owner.open(owner.entries[selected.clamp(0, owner.entries.length - 1)]),
      );
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  void dispose() {
    owner.removeListener(changed);
    owner.dispose();
    query.dispose();
    focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => renderQuickJump(this);
}
