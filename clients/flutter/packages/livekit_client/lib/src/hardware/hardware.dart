// Copyright 2024 LiveKit, Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:meta/meta.dart';

import '../audio/audio_manager.dart';
import '../audio/audio_session.dart';
import '../logger.dart';
import '../support/platform.dart';

class MediaDevice {
  const MediaDevice(this.deviceId, this.label, this.kind, this.groupId);

  final String deviceId;
  final String label;
  final String kind;
  final String? groupId;

  @override
  bool operator ==(covariant MediaDevice other) {
    if (identical(this, other)) return true;

    return other.deviceId == deviceId && other.kind == kind && other.label == label && other.groupId == groupId;
  }

  @override
  int get hashCode {
    return deviceId.hashCode ^ kind.hashCode ^ label.hashCode;
  }

  @override
  String toString() {
    return 'MediaDevice{deviceId: $deviceId, label: $label, kind: $kind, groupId: $groupId}';
  }
}

class Hardware {
  Hardware._internal() {
    rtc.navigator.mediaDevices.ondevicechange = _onDeviceChange;
  }

  static final Hardware instance = Hardware._internal();

  final StreamController<List<MediaDevice>> onDeviceChange = StreamController.broadcast();

  MediaDevice? selectedAudioInput;

  MediaDevice? selectedAudioOutput;

  MediaDevice? selectedVideoInput;

  Timer? _deviceChangeDebounce;
  Future<void>? _deviceChangeRefresh;
  bool _deviceChangePending = false;

  @Deprecated('Use AudioManager.instance.isSpeakerOutputPreferred instead')
  bool? get speakerOn => AudioManager.instance.isSpeakerOutputPreferred;

  @Deprecated('Use AudioManager.instance.isSpeakerOutputPreferred instead')
  bool get preferSpeakerOutput => AudioManager.instance.isSpeakerOutputPreferred;

  /// if true, will force speaker output even if headphones or bluetooth is connected
  @Deprecated('Use AudioManager.instance.isSpeakerOutputForced instead')
  bool get forceSpeakerOutput => AudioManager.instance.isSpeakerOutputForced;

  // Whether automatic native audio configuration is enabled. If disabled,
  // Native.configureAudio is not called and the app is responsible for
  // configuring the native audio session manually.
  //
  // Backed by [AudioManager] so there is a single source of truth for the
  // management mode. See [AudioManager.setAudioSessionManagementMode].
  @Deprecated('Use AudioManager.instance.managementMode instead')
  bool get isAutomaticConfigurationEnabled => AudioManager.instance.managementMode != AudioSessionManagementMode.manual;

  @Deprecated('Use AudioManager.instance.setAudioSessionManagementMode instead')
  void setAutomaticConfigurationEnabled({required bool enable}) {
    unawaited(
      AudioManager.instance.setAudioSessionManagementMode(
        enable ? AudioSessionManagementMode.automatic : AudioSessionManagementMode.manual,
      ),
    );
  }

  Future<List<MediaDevice>> enumerateDevices({String? type}) async {
    final infos = await rtc.navigator.mediaDevices.enumerateDevices();
    var devices = infos.map((e) => MediaDevice(e.deviceId, e.label, e.kind!, e.groupId)).toList();
    _syncSelectedDevices(devices);
    if (type != null && type.isNotEmpty) {
      devices = devices.where((d) => d.kind == type).toList();
    }
    return devices;
  }

  Future<List<MediaDevice>> audioInputs() async {
    return enumerateDevices(type: 'audioinput');
  }

  Future<List<MediaDevice>> audioOutputs() async {
    return enumerateDevices(type: 'audiooutput');
  }

  Future<List<MediaDevice>> videoInputs() async {
    return enumerateDevices(type: 'videoinput');
  }

  Future<void> selectAudioOutput(MediaDevice device) async {
    if (lkPlatformIs(PlatformType.web) || lkPlatformIs(PlatformType.iOS)) {
      logger.warning('selectAudioOutput is not supported on Web or iOS');
      return;
    }
    selectedAudioOutput = device;
    await rtc.Helper.selectAudioOutput(device.deviceId);
  }

  Future<void> selectAudioInput(MediaDevice device) async {
    if (lkPlatformIs(PlatformType.web) || lkPlatformIsMobile()) {
      logger.warning('selectAudioInput is only supported on Windows/macOS');
      return;
    }
    await rtc.Helper.selectAudioInput(device.deviceId);
    // Keep the SDK cache aligned with the route accepted by the native ADM.
    selectedAudioInput = device;
  }

  @Deprecated('Use AudioManager.instance.setSpeakerOutputPreferred instead')
  Future<void> setPreferSpeakerOutput(bool enable) => AudioManager.instance.setSpeakerOutputPreferred(enable);

  @Deprecated('Use AudioManager.instance.canSwitchSpeakerphone instead')
  bool get canSwitchSpeakerphone => AudioManager.instance.canSwitchSpeakerphone;

  /// [enable] set speakerphone on or off, by default wired/bluetooth headsets will still
  /// be prioritized even if set to true.
  /// [forceSpeakerOutput] if true, will force speaker output even if headphones
  /// or bluetooth is connected.
  @Deprecated('Use AudioManager.instance.setSpeakerOutputPreferred instead')
  Future<void> setSpeakerphoneOn(bool enable, {bool forceSpeakerOutput = false}) =>
      AudioManager.instance.setSpeakerOutputPreferred(enable, force: forceSpeakerOutput);

  Future<rtc.MediaStream> openCamera({MediaDevice? device, bool? facingMode}) async {
    final constraints = <String, dynamic>{
      if (facingMode != null) 'facingMode': facingMode ? 'user' : 'environment',
    };
    if (device != null) {
      if (lkPlatformIs(PlatformType.web)) {
        constraints['deviceId'] = device.deviceId;
      } else {
        constraints['optional'] = [
          {'sourceId': device.deviceId},
        ];
      }
    }
    selectedVideoInput = device;
    return rtc.navigator.mediaDevices.getUserMedia(<String, dynamic>{
      'audio': false,
      'video': device != null ? constraints : true,
    });
  }

  /// Requests permission to capture the screen before starting a screen share.
  ///
  /// On Android this shows the MediaProjection consent dialog, on macOS it
  /// triggers the screen recording permission check. Returns true when
  /// permission was granted. On platforms that do not require an upfront
  /// request this is a no-op that returns true, so it is safe to call
  /// unconditionally.
  ///
  /// Experimental: this API may change in a future release.
  @experimental
  Future<bool> requestCapturePermission({bool fullScreenOnly = false}) async {
    if (lkPlatformIs(PlatformType.android) || lkPlatformIs(PlatformType.macOS)) {
      return rtc.Helper.requestCapturePermission(fullScreenOnly: fullScreenOnly);
    }
    return true;
  }

  void _syncSelectedDevices(List<MediaDevice> devices) {
    final inputs = devices.where((element) => element.kind == 'audioinput');
    final outputs = devices.where((element) => element.kind == 'audiooutput');
    final videos = devices.where((element) => element.kind == 'videoinput');
    if (selectedAudioInput == null || !inputs.any((device) => device.deviceId == selectedAudioInput!.deviceId)) {
      selectedAudioInput = inputs.firstOrNull;
    }
    if (selectedAudioOutput == null || !outputs.any((device) => device.deviceId == selectedAudioOutput!.deviceId)) {
      selectedAudioOutput = outputs.firstOrNull;
    }
    if (selectedVideoInput == null || !videos.any((device) => device.deviceId == selectedVideoInput!.deviceId)) {
      selectedVideoInput = videos.firstOrNull;
    }
  }

  void _onDeviceChange(dynamic _) {
    _deviceChangePending = true;
    _deviceChangeDebounce?.cancel();
    _deviceChangeDebounce = Timer(const Duration(milliseconds: 150), () {
      unawaited(_flushDeviceChange());
    });
  }

  Future<void> _flushDeviceChange() async {
    if (!_deviceChangePending) return;
    final pending = _deviceChangeRefresh;
    if (pending != null) {
      await pending;
      return;
    }
    _deviceChangePending = false;
    final operation = enumerateDevices();
    _deviceChangeRefresh = operation;
    try {
      final devices = await operation;
      onDeviceChange.add(devices);
    } finally {
      if (identical(_deviceChangeRefresh, operation)) {
        _deviceChangeRefresh = null;
      }
      if (_deviceChangePending) unawaited(_flushDeviceChange());
    }
  }
}
