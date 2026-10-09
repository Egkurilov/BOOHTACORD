# UI/UX 2026 release gate

Status: `NOT_RUN` — this is an acceptance protocol, not a release approval. The parent issue #289 stays open until a release owner reviews completed evidence and explicitly accepts or resolves the remaining gaps.

## Evidence trail

[`evidence/qa/uiux-2026-epic-289-2026-10-09.md`](../../evidence/qa/uiux-2026-epic-289-2026-10-09.md) is the current issue → implementation → test → evidence map. Record the commit, build metadata, commands, artifact paths, viewport, platform, and result in that file as each slice lands. `[skip ci]` pushes have local evidence only; they do not create GitHub Actions artifacts.

## User task baseline and comparison

Use the same account fixture, data set, browser/device, viewport, input method, and task wording for baseline and post-change runs. Recruit real testers; do not treat automated checks or developer estimates as user measurements.

| # | Task | Platform / viewport | Baseline result, time, errors/backtracks | Post-change result, time, errors/backtracks | Evidence |
| --- | --- | --- | --- | --- | --- |
| 1 | Find and open a text channel | Web desktop / mobile | `NOT_RUN` | `NOT_RUN` | — |
| 2 | Send a message and reply to it | Web desktop / mobile | `NOT_RUN` | `NOT_RUN` | — |
| 3 | Find a direct message and search its history | Web desktop / mobile | `NOT_RUN` | `NOT_RUN` | — |
| 4 | Find a guild member | Web desktop / mobile | `NOT_RUN` | `NOT_RUN` | — |
| 5 | Create a text channel in a section | Web desktop / mobile | `NOT_RUN` | `NOT_RUN` | — |
| 6 | Change a member role | Web desktop / mobile | `NOT_RUN` | `NOT_RUN` | — |
| 7 | Join a voice channel | Web desktop / mobile | `NOT_RUN` | `NOT_RUN` | — |
| 8 | Start a screen demonstration | Web desktop / mobile | `NOT_RUN` | `NOT_RUN` | — |

For each attempt, record completion (yes/no), time from task prompt to completion, wrong actions, backtracking, help requested, and any blocking error. Run the same tasks for Flutter on each supported release platform after physical builds are available. Report medians and completion/error counts; keep each platform separate.

**Targets:** `TBD — release owner approval required`. No success/time/error threshold has been inferred from this code review. Do not declare improvement until baseline and post-change runs have comparable tester and platform samples.

## Platform and artifact matrix

| Surface | Current evidence | Release acceptance |
| --- | --- | --- |
| Web / Chrome desktop and mobile viewports | Local unit/build/accessibility and selected Playwright fixtures are recorded in the evidence file. | `NOT_RUN` — task-based tester baseline/post-change, final screenshots, and owner review. |
| Flutter / macOS | Widget and analyzer results are recorded in the evidence file; physical macOS/Chrome targets were discovered. | `NOT_RUN` — native settings/audio smoke and task-based usability capture. |
| Flutter / Android | Platform-specific widget coverage exists. No Android device was discovered. | `NOT_RUN` — physical settings, IME, voice, screen capture, and TalkBack acceptance. |
| Flutter / iOS | Platform-specific widget coverage exists. No iOS device was discovered. | `NOT_RUN` — physical settings, IME, voice, screen capture, and VoiceOver acceptance. |
| Flutter / Windows | Platform-specific widget coverage exists. No Windows device was discovered. | `NOT_RUN` — physical interaction, voice/stream, and screen-reader acceptance. |

The original 41 reference screenshots are present in [`artifacts/ui-ux-screenshots.zip`](../../artifacts/ui-ux-screenshots.zip). Current shell/DOM/widget tests are regression evidence, not full-app before/after comparison against those assets. No screenshot or device gate is passed by this document.

## Rollout and rollback

- Roll out UI-only changes through the existing Web and Flutter release processes in separate platform cohorts. Keep each cohort's build identifier and evidence link with the release record.
- Protocol, database, ACL, session-cookie, and media transport contracts are outside this UI package; any proposed contract change requires its own review and release plan.
- Web rollback: redeploy the last known-good immutable Web artifact or revert the UI-only commit and produce a new artifact.
- Flutter rollback: halt the affected platform cohort and use the existing platform release rollback/update process to return to its last known-good build. Record store/desktop packaging constraints before rollout.
- Release owner and per-platform rollback owner: `TBD — assign before rollout`.
- Release decision: `NO-GO / NOT_RUN` until tester evidence, platform acceptance, artifact references, owner assignments, and screenshot gaps are reviewed. An owner may record accepted exceptions with rationale and follow-up issue; do not relabel `NOT_RUN` as `PASS`.
