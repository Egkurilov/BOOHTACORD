import 'dart:convert';

import 'package:boohtacord_desktop/src/features/screen/sender_metadata/descriptor.dart';

ScreenShareSenderDescriptor? parse(Map<String, Object?> value) =>
    parseScreenShareDescriptor(jsonEncode(value));

Map<String, Object?> descriptor({int generation = 4, int revision = 12}) => {
  'schema_version': 1,
  'scope': {
    'origin_id': 'origin-a',
    'account_id': 'account-a',
    'room_id': 'room-a',
    'media_session_id': 'session-a',
    'publication_generation': generation,
    'operation_revision': revision,
  },
  'mode': 'motion',
  'publisher_state': 'sharing',
  'viewer_state': 'idle',
  'requested_profile_id': 'P1080_60',
  'effective_profile': {
    'capture': {'max_width': 1920, 'max_height': 1080, 'max_fps': 60},
    'encoding': {
      'codec': null,
      'layers': [
        {
          'rid': null, 'width': 1920, 'height': 1080, 'max_fps': 60,
          'max_bitrate_bps': 8000000, 'scale_down_by': 1, 'active': true,
        },
      ],
    },
  },
  'layer_topology': 'single-layer',
  'profile_revision': 1,
  'capabilities': {
    'live_update': true, 'republish_without_recapture': false,
    'simulcast': false,
  },
  'reason_codes': ['user-request'],
};
