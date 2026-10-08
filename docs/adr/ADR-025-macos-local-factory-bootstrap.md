# ADR025: macOS local factory bootstrap

Status: accepted for implementation under current #177 and owner request to
analyse the conflict with #178 and complete the issue. Date:2026-10-09.

## Decision
Preserve the one-guild secure session/media protocol. Keep the bootstrap in the
local flutter_webrtc API, separate from Room and capture. On macOS only, create
one empty local PeerConnection after normal WebRTC initialization, close it and
dispose it including its Flutter event subscription before marking factory ready.
Concurrent requests share an operation. Creation/cleanup failure remains an error
and allows explicit retry. Other native platforms keep initialize-only behavior.

The local PC has no ICE servers, SDP exchange, tracks or data channels; no offer,
descriptions, microphone permission, capture, room connection or publication runs.
This exercises the same ADM lazy initialization used by first Join and preserves
ADM device identifiers. CoreAudio enumeration would create a second identifier
source and require unproven mapping to the current selection implementation.

This revises the obsolete blanket no-local-PC constraint recorded in closed #178:
pre-Join network/media sessions remain prohibited, the immediately released local
factory bootstrap is permitted by current #177. Initialize-only cannot be treated
as proof of factory readiness. No custom SFU or Android ADR006 change is involved.

## Evidence and limits
MethodChannel regression separates initialize/default fixture inventory from
factory ready/full fixture inventory and checks event cancellation before native
dispose. This validates Dart calls and ownership, not physical Mac hardware.
#184 remains mandatory for cold start, privacy indicator, hotplug, selection,
reconnect and Debug/Profile/Release on the installed source-bound native build.
