import 'package:flutter/material.dart';

class GuildName extends StatelessWidget {
  const GuildName(this.name, {super.key, this.style});
  final String name;
  final TextStyle? style;
  @override
  Widget build(BuildContext context) => Tooltip(
    message: name,
    child: Text(
      name,
      style: style,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      semanticsLabel: name,
    ),
  );
}
