import 'dart:async';

import 'package:boohtacord_desktop/src/core/session/scope.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:boohtacord_desktop/src/features/direct/conversations/candidate_page.dart';
import 'package:boohtacord_desktop/src/features/workspace/quick_jump/state/controller.dart';
import 'package:boohtacord_desktop/src/features/workspace/quick_jump/state/effects.dart';
export 'package:boohtacord_desktop/src/models.dart';
export 'package:boohtacord_desktop/src/features/workspace/quick_jump/state/controller.dart';

class JumpApi extends ApiClient {
  final requests = <String?>[];
  final pending = <Completer<DirectCandidatePage>>[];
  List<DirectConversation> directs = [];
  int creates = 0, topologyReads = 0;
  bool deny = false;
  Future<String>? createResult;
  ChannelTopology serverTopology = const ChannelTopology(
    revision: 1,
    categories: [],
  );
  @override
  Future<DirectCandidatePage> directMessageCandidatePage({String? after}) {
    requests.add(after);
    final result = Completer<DirectCandidatePage>();
    pending.add(result);
    return result.future;
  }

  @override
  Future<List<DirectConversation>> directMessages() async => directs;
  @override
  Future<String> openDirectMessage(String id) async {
    creates++;
    if (deny) throw const ApiFailure('Denied', status: 403, code: 'FORBIDDEN');
    return createResult == null ? 'dm-new' : await createResult!;
  }

  @override
  Future<ChannelTopology> topology() async {
    topologyReads++;
    return serverTopology;
  }
}

class JumpHarness {
  final api = JumpApi();
  final scope = SessionScope();
  String? account = 'self';
  ChannelTopology? topology;
  List<DirectConversation> directs = [];
  DirectConversation? openedDirect;
  GuildChannel? openedChannel;
  late final owner = QuickJumpController(
    api,
    scope,
    readAccount: () => account,
    readTopology: () => topology,
    readDirects: () => directs,
    effects: QuickJumpEffects(
      acceptTopology: (v) => topology = v,
      acceptDirects: (v) => directs = v,
      openChannel: (v) async {
        openedChannel = v;
      },
      openDirect: (v) async {
        openedDirect = v;
      },
    ),
  );
}
