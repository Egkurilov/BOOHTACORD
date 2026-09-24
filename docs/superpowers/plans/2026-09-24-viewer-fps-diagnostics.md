# Viewer FPS diagnostics

Packet: viewer-side screen playback diagnostics. The user reports a continuously moving macOS screen share appearing at roughly 1 FPS on a Windows viewer. A server snapshot showed no obvious LiveKit CPU pressure; it does not identify the bottleneck.

1. Add a focused, disposable video-frame observer for the selected HTML video. Count presented frames over a timed window; return unknown when the browser lacks a frame callback instead of inventing an FPS. Test slow, normal, reset, and cleanup cases.
2. Feed the observed FPS into the existing viewer quality line and diagnostics. Keep target/source FPS unknown on a remote stream. Reset measurements when selection changes or playback empties. Update focused viewer tests.
3. Run the nearest frontend tests and production build. Do not tune encoding or claim the 1 FPS is fixed without before/after sender and receiver measurements. Test 720p/30 as an operator-controlled mitigation after the UI reaches production.

Stop condition: measured viewer FPS is visible and verified by tests/build, with the underlying Mac capture/encode versus transport cause remaining explicitly unproven until sender stats or paired measurements exist. No production deploy from the current mixed worktree.
