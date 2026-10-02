import 'dart:ffi';
import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';

import '../../app_version.dart';
import 'model.dart';

String _architecture() => switch (Abi.current()) {
  Abi.androidArm64 || Abi.windowsArm64 => 'arm64',
  Abi.androidArm => 'armv7',
  Abi.androidX64 || Abi.windowsX64 => 'x64',
  _ => 'any',
};

class NativeUpdateIdentity {
  const NativeUpdateIdentity(this.local, this.selector, this.environment);
  final LocalUpdateIdentity local;
  final UpdateSelector selector;
  final UpdateEnvironment environment;

  static Future<NativeUpdateIdentity> load() async {
    final package = await PackageInfo.fromPlatform();
    final platform = Platform.isAndroid ? 'android' : Platform.isWindows ? 'windows' : Platform.operatingSystem;
    final arch = _architecture();
    final selector = Platform.isAndroid ? UpdateSelector.android(arch)
      : Platform.isWindows ? UpdateSelector.windows(arch)
      : Platform.isIOS ? UpdateSelector.ios(arch)
      : UpdateSelector.macos(arch);
    return NativeUpdateIdentity(
      LocalUpdateIdentity(releaseId:appReleaseId, releaseOrder:appReleaseOrder, platform:platform, version:appVersionName, nativeBuild:appBuildNumber, installedVersion:package.version, installedBuild:package.buildNumber, packageName:package.packageName, expectedPackageName:Platform.isAndroid ? 'ru.boohtacord.app' : Platform.isWindows ? 'boohtacord_desktop' : null),
      selector,
      UpdateEnvironment(osVersion:_osVersion(), arch:arch),
    );
  }
}

String _osVersion() => RegExp(r'\d+(?:\.\d+)*').firstMatch(Platform.operatingSystemVersion)?.group(0) ?? '0';
