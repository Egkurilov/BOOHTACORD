import 'package:livekit_client/livekit_client.dart';

import '../../../core/session/scope.dart';
import '../lifecycle/controller.dart';

bool isCurrentQualitySession(
  ScreenShareController owner,
  SessionTicket ticket,
  SessionTicket transportTicket,
  int server,
  int expected,
  Room? room,
) =>
    !owner.disposed &&
    ticket.isActive &&
    transportTicket.isActive &&
    server == owner.api.transport.session.serverRevision &&
    expected == owner.revision &&
    room != null &&
    identical(owner.readRoom(), room);
