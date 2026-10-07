import 'package:boohtacord_desktop/src/features/admin/topology/panel.dart';
import 'package:boohtacord_desktop/src/features/admin/topology/actions.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:flutter/material.dart';

const topologyLongName = 'Очень длинное название раздела и канала для адаптивной панели';
final topologyVoiceChannel = GuildChannel(
  id: 'voice',
  name: topologyLongName,
  kind: ChannelKind.voice,
  admissionClosed: true,
);
final topologyCategories = [
  ChannelCategory(
    id: 'category',
    name: topologyLongName,
    channels: [topologyVoiceChannel],
  ),
];
final topologyTestActions = TopologyActions(
  createCategory: (_) async => null,
  createChannel: (_, __, ___, ____) async {},
  renameCategory: (_, __, ___) async {},
  deleteCategory: (_, __) async {},
  reorderCategory: (_, __, ___) async {},
  renameChannel: (_, __, ___) async {},
  saveDescription: (_, __, ___) async {},
  moveChannel: (_, __, ___) async {},
  reorderChannel: (_, __, ___, ____) async {},
  archiveTextChannel: (_, __) async {},
  closeVoiceAdmission: (_, __) async {},
);

Widget topologyTestApp(List<ChannelCategory> categories) => MaterialApp(
  home: Scaffold(
    body: AdminTopologyPanel(
      categories: categories,
      revision: 1,
      busy: false,
      status: null,
      error: null,
      actions: topologyTestActions,
    ),
  ),
);
