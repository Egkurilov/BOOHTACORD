import '../../../services/api_client.dart';
import 'load.dart';
import 'reset.dart';
import 'save.dart';
import 'state.dart';
import 'voice_kick.dart';

class AdminMembersController extends AdminMembersState
    with AdminMembersLoad, AdminMembersSave, AdminMembersReset, AdminMembersVoiceKick {
  AdminMembersController(ApiClient api) : super(api);
}
