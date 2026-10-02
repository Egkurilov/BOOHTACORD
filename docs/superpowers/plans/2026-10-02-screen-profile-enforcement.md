# Screen profile enforcement implementation plan

**Goal:** Apply the selected screen profile at publication and detect/reset drift once.
**Architecture:** A browser-owned profile guard follows the current LiveKit track and
profile generation. The existing sender diagnostic poll drives a five-second check.
Validated media.sample fields carry guard state; existing screen feedback shows failure.
**Tech stack:** Vue/TypeScript, LiveKit Client 2.22.3, Go, OpenTelemetry.

## Operating brief

- Route: split_first; backlog T-005 depends on T-004; physical acceptance stays open.
- Baseline: c78ebdbf, observed 1080p60 target with actual 2560x1440 frames.
- Leaf: clients/web/src/voice/screen_profile; boundary: exact publishing/diagnostic edges.
- Preserve audio, ACL, adaptiveStream/dynacast, source aspect ratio and in-call profile changes.
- Limits: 120 source lines, 16 production/direct test files per leaf.
- Stop: focused/native checks pass; trace fields validated; signed deployment verified.

## 1. Selected profile at startup

Files: new screen_profile/{policy,apply}.ts and their colocated tests;
media_publishing.ts, livekit_room_factory.ts, livekit_screen_publishing.spec.ts.

1. Fail the existing initial-publication test by expecting the requested dimensions:
   `expect(capture.resolution).toEqual({width: 1920, height: 1080, frameRate: 60})`.
2. Parse the profile once into resolution, FPS, capture limits and bitrate.
3. Apply capture maximums and proportional encoder scales, preserving layer active flags.
4. On explicit quality changes, raise/lower capture constraints without a second picker.
5. Abort stale track/generation writes; clean up an initial share when configuration fails.

## 2. Bounded profile guard

Files: screen_profile/{types,inspect,guard}.ts and focused policy/race tests;
screen_sender_reporting.ts, screen_diagnostics.ts, screen_feedback.ts.

Interface: `apply(profile): Promise<void>`, `check(): Promise<void>`, `stop(): void`.
The guard exposes `{status, reason, attempts, captureWidth, captureHeight, captureFps}`.

1. Test three consecutive drift checks, exactly one repair, and verification after repair.
2. Test reduced resolution/FPS, inactive layers and absent stats without forced recovery.
3. Test replacement, stop and profile changes during stats/constraint/setParameters awaits.
4. Serialize profile application; recheck generation before every media mutation.
5. Drive checks every five seconds; update the expected profile on successful user changes.
6. Keep failure visible until explicit profile change, track replacement or share stop.

## 3. Trace and delivery

Files: voice/report_media/{fields,types}.ts; backend observability report schema,
validation and media.sample exporter with focused tests; exact API schema if present.

1. Add bounded optional guard/capture fields, fixed status/reason enums and attempt 0/1.
2. Reject spoofed/arbitrary values and preserve omission of unavailable measurements.
3. Test the complete report-to-span path, including zero attempts and measured capture.
4. Run focused Vitest, web tests/build/import guard, focused Go tests and contracts.
5. Save evidence; inspect changed sizes/status, commit explicit paths, push and verify CI.
6. Use the authorized master/deployment path; verify signed installed revision and HTTPS.
   A browser reload/new share is required to exercise new client code; do not claim live
   media improvement until new samples or a controlled moving-scene test demonstrate it.
