import '../../../models.dart';
import '../../../core/http/facade_base.dart';
import 'api.dart';

mixin OwnProfileFacade on ApiFacadeBase {
  late final _ownProfile = OwnProfileApi(transport);

  Future<OwnProfile> ownProfile() => _ownProfile.ownProfile();

  Future<OwnProfile> updateOwnProfile(String displayName) =>
      _ownProfile.updateOwnProfile(displayName);

  Future<void> changePassword(String currentPassword, String newPassword) =>
      _ownProfile.changePassword(currentPassword, newPassword);
}
