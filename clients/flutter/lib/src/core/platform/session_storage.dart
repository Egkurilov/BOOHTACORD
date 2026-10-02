import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Preserve the legacy macOS Keychain service: ad-hoc builds do not have
// Data Protection Keychain entitlements, and older items can block startup.
const macOsSessionOptions = MacOsOptions(
  accountName: 'ru.boohtacord.boohtacordDesktop.session.v3',
  usesDataProtectionKeychain: false,
);

FlutterSecureStorage sessionStorage() => Platform.isMacOS
    ? const FlutterSecureStorage(mOptions: macOsSessionOptions)
    : const FlutterSecureStorage();
