import 'package:boohtacord_desktop/src/features/admin/voice_timeout/model.dart';

import '../admin_topology_fake_api.dart';

const target = '33333333-3333-4333-8333-333333333333';

class TimeoutLaunchApi extends TopologyTestApi {
  int reads = 0;
  String? readAccount;
  @override
  Future<VoiceTimeoutState> getVoiceTimeout(String id) async {
    reads++;
    readAccount = id;
    return const VoiceTimeoutState(false, null, null, 0, false);
  }
}
