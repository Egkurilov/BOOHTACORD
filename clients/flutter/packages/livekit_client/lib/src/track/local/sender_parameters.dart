// Copyright 2026 LiveKit, Inc.
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

import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:meta/meta.dart';
import 'package:synchronized/synchronized.dart';

final _senderLocks = Expando<Lock>('LiveKit RTP sender parameter lock');

@internal
Future<T> withSenderParametersLock<T>(
  rtc.RTCRtpSender sender,
  Future<T> Function() operation,
) {
  final lock = _senderLocks[sender] ??= Lock();
  return lock.synchronized(operation);
}
