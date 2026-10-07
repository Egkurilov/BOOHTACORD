import 'package:flutter/material.dart';

class AdminMembersLoadingState extends StatelessWidget {
  const AdminMembersLoadingState({super.key});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 12),
        const Semantics(
          key: ValueKey('admin-members-loading'),
          liveRegion: true,
          child: Text('Загружаем список участников…'),
        ),
      ],
    ),
  );
}
