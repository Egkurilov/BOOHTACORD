import 'dart:typed_data';

import '../../models.dart';
import '../../features/profile/state/controller.dart';
import '../composition/owners.dart';

mixin AppProfileAccess on AppOwners {
  OwnProfile? get profile => profileOwner.profile;

  set profile(OwnProfile? value) => profileOwner.profile = value;

  bool get profileLoading => profileOwner.profileLoading;

  set profileLoading(bool value) => profileOwner.profileLoading = value;

  String? get profileLoadError => profileOwner.profileLoadError;

  set profileLoadError(String? value) => profileOwner.profileLoadError = value;

  bool get profileSaving => profileOwner.profileSaving;

  set profileSaving(bool value) => profileOwner.profileSaving = value;

  int get avatarRevision => profileOwner.avatarRevision;

  Future<void> refreshProfile() => profileOwner.refreshProfile();

  Future<bool> saveDisplayName(String value) =>
      profileOwner.saveDisplayName(value);

  Future<bool> updatePassword(String current, String next) =>
      profileOwner.updatePassword(current, next);

  Future<bool> uploadAvatar(Uint8List bytes, String contentType) =>
      profileOwner.uploadAvatar(bytes, contentType);

  Future<bool> deleteAvatar() => profileOwner.deleteAvatar();
}
