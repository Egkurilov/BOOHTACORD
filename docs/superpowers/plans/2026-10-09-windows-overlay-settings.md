# Windows overlay settings — #112

Packet: small_direct, after the preserved workspace conversion. Exact native boundary: current VoiceOverlayFeed → WindowsVoiceOverlayClient → runner MethodChannel → existing sibling VoiceOverlayWindow. UI binds through the converted voice_dock child; media ownership remains untouched.

Preserve existing account speaker-filter preference and bounded display-only snapshot. Add typed account-local settings for enabled, normalized placement/monitor, scale, opacity, cap and hotkey; default opt-in off. The editor is explicit, permits dragging without activating the window, and returns to click-through on close, logout, hide or disconnect. Reject invalid settings on both sides; do not send account IDs.

Use native monitor work areas, DPI-scaled layout and clamping after display changes. Register a customizable modifier+F-key with MOD_NOREPEAT, report conflicts, unregister while disabled/disconnected and on teardown. Native hotkey visibility survives live speaker updates. Window is destroyed while inactive and recreated on a later accepted current-session snapshot.

Split changed oversized native decoder/window implementations into typed lifecycle, snapshot decode, appearance, placement and event leaves and rewire CMake. No verifier exceptions. Add focused failing model/preferences/native-bridge tests, then actual settings widgets, existing overlay tests and all workspace tests; analyze and build Windows locally or retain exact unavailable result.

Technical source decision: same-process Win32 system window, existing engine/Room, no game injection. Event-driven snapshots; no polling loop. Initial windowed/borderless boundary. Physical game/FPS/anti-cheat/performance acceptance remains QA; do not claim unmeasured hardware budgets.

Stop: source settings/hotkey/edit/DPI behavior and native compilation evidence; owner report identifies physical acceptance separately. Limits: source target100/hard120, leaf target8/hard16.
