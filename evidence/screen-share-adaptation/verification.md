# Screen-share quality adaptation policy verification

- Date: 2026-10-07
- GitHub issue: #169
- Implementation base: `451eb8836b50c4f04524df8aeebeb8fa939ad2d6`
- Scope: pure web slow-policy/state transitions under `clients/web/src/voice/screen_adaptation/`.
- Rollout state: inert. No runtime caller supplies the required evidence-backed calibration; the catalog also keeps `slowSupervisor.enabledByDefault` false.

## Verification

| Check | Result |
|---|---|
| Focused adaptation and existing session publisher tests | PASS — 10 tests across 3 files |
| `npx vue-tsc --noEmit` | PASS |
| Full Web suite | NOT_RUN |
| Live SFU paired run, hardware/thermal and bandwidth calibration | NOT_RUN |
| Voice-first paired acceptance and two-receiver runtime observation | NOT_RUN |

The policy accepts only fresh generation-tagged observations with distinct provenance, separates shared publisher pressure from receiver-local pressure, requires calibrated consecutive windows and dwell/recovery intervals, and clamps recovery to the selected profile ceiling. Hidden, static, paused, warming, stale, unknown-subscriber, and no-subscriber windows reset hysteresis without requesting a profile change. A transition changes the video profile only and is labeled `voice-first`.

No threshold values are enabled by default. Test fixtures exercise the state machine and are not device/network calibration evidence. Issue #158's baseline record reports live SFU, physical display, and hardware/bandwidth-shaping checks as `NOT_RUN`; production activation and performance claims remain gated on those measurements and a runtime integration that supplies the required provenance-tagged windows.
