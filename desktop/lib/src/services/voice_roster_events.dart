import 'dart:convert';

import '../models.dart';

List<VoiceRoomRoster>? parseVoiceRosterEvent(String line) {
  if (!line.startsWith('data: ')) return null;
  final value = jsonDecode(line.substring(6));
  if (value is! Map<String, dynamic> || value['channels'] is! List) {
    throw const FormatException('Invalid voice roster event.');
  }
  final channels = (value['channels'] as List)
      .map((item) => VoiceRoomRoster.fromJson(item as Map<String, dynamic>))
      .toList(growable: false);
  if (channels.map((item) => item.channelId).toSet().length !=
      channels.length) {
    throw const FormatException('Duplicate voice roster channel.');
  }
  return channels;
}
