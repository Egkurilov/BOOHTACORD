# Windows voice and stream follow-up

Route: split_first. Scope: Flutter voice capture, participant stream status, screen audio playback, and Windows audio processing. Preserve existing voice and screen behavior.

1. Add a focused audio configuration test for the microphone's 128 kbit/s Opus ceiling and capture processing defaults. Set the Room publish options explicitly and run the test.
2. Add a participant status widget test for a published screen without a thumbnail or subscription. Show a stream icon in the compact participant strip and use publication state for the other room indicators. Run the nearest widget tests.
3. Verify the screen audio mute path from control through per-track volume and resubscription. Fix any failure found. Do not claim acoustic acceptance from source review.
4. Add a Windows-specific regression test for applying noise suppression during a call. Use recapture on Windows because its LiveKit plugin has no runtime processing method, and keep the previous setting on failure. Run focused Flutter tests, analyze, and a Windows build.

Stop when all four code paths are checked, native validation is complete, and remaining physical two-party audio checks are recorded as unverified.
