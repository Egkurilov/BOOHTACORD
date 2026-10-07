import 'package:boohtacord_desktop/src/features/admin/audit/controller.dart';
import 'package:boohtacord_desktop/src/features/admin/audit/panel.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:flutter/material.dart';

AdminAuditEvent auditEvent({
  required String id,
  required String type,
  DateTime? at,
  String? actorId = 'actor-1',
  String? actorName = 'Moderator',
  String? actorLogin = 'mod',
  String? targetId,
  String? targetName,
  String? targetLogin,
}) => AdminAuditEvent(
  id: id,
  eventType: type,
  createdAt: at ?? DateTime(2026, 10, 6, 10, 15),
  actorUserId: actorId,
  actorDisplayName: actorName,
  actorLogin: actorLogin,
  targetUserId: targetId,
  targetDisplayName: targetName,
  targetLogin: targetLogin,
);

Widget auditApp(AdminAuditController controller) => MaterialApp(
  home: Scaffold(body: AdminAuditPanel(controller: controller)),
);
