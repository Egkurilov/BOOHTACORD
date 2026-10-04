import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../app_state.dart';

class AuthenticatedAvatar extends StatefulWidget {
  const AuthenticatedAvatar({
    super.key,
    required this.state,
    required this.name,
    required this.radius,
    this.avatarUrl,
    this.backgroundColor = const Color(0xFF365ACA),
    this.fallbackFontSize,
    this.fallbackText,
    this.fallbackColor = Colors.white,
    this.borderColor,
    this.borderWidth = 0,
  });

  final AppState state;
  final String name;
  final double radius;
  final String? avatarUrl;
  final Color backgroundColor;
  final double? fallbackFontSize;
  final String? fallbackText;
  final Color fallbackColor;
  final Color? borderColor;
  final double borderWidth;

  @override
  State<AuthenticatedAvatar> createState() => _AuthenticatedAvatarState();
}

class _AuthenticatedAvatarState extends State<AuthenticatedAvatar> {
  Future<Uint8List>? _bytes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant AuthenticatedAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.avatarUrl != widget.avatarUrl ||
        oldWidget.state.avatarRevision != widget.state.avatarRevision ||
        oldWidget.state.api != widget.state.api) {
      _load();
    }
  }

  void _load() {
    final url = widget.avatarUrl;
    _bytes = url == null || url.trim().isEmpty
        ? null
        : widget.state.api.avatarBytes(url);
  }

  Widget _fallback() => ColoredBox(
    color: widget.backgroundColor,
    child: Center(
      child: Text(
        widget.fallbackText ??
            (widget.name.trim().isEmpty
                ? '?'
                : widget.name.characters.first.toUpperCase()),
        style: TextStyle(
          color: widget.fallbackColor,
          fontSize: widget.fallbackFontSize ?? widget.radius * .72,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final diameter = widget.radius * 2;
    final image = _bytes == null
        ? _fallback()
        : FutureBuilder<Uint8List>(
            future: _bytes,
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.hasError) return _fallback();
              return Image.memory(
                snapshot.data!,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => _fallback(),
              );
            },
          );
    return Semantics(
      image: true,
      label: 'Аватар ${widget.name}',
      child: Container(
        width: diameter,
        height: diameter,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: widget.borderColor == null || widget.borderWidth <= 0
              ? null
              : Border.all(
                  color: widget.borderColor!,
                  width: widget.borderWidth,
                ),
        ),
        padding: EdgeInsets.all(widget.borderWidth),
        child: ClipOval(child: image),
      ),
    );
  }
}
