# GuildChat Design Fidelity — Implementation Plan

> **For agentic workers:** Execute the tasks in order with focused tests before implementation. Checkbox states are evidence, not a claim of pixel-perfect acceptance.

**Goal:** Match the authenticated web workspace to the supplied GuildChat reference across chat, voice, member roster, and screen viewing; validate the production result before closing T-050.

**Architecture:** Keep one-guild ACL and LiveKit media ownership. In voice layout, reserve the main area for the room grid and open the verified participant roster on demand; in text layout, show guild presence groups backed by active authenticated realtime sessions. Presence is `online` when at least one authenticated realtime WebSocket is active, `offline` when the registry knows there are none, and `unknown` when no provider/data is available. Never infer presence from role or fabricate participants.

**Tech Stack:** Vue 3, TypeScript, Pinia, CSS; Go, PostgreSQL-backed member profiles, authenticated WebSocket session lifecycle; Vitest and Go tests.

---

**Source:** `GuildChat_Design_System_v1.0.zip` contracts and supplied dark/1440/640 reference screenshots. Keep this packet limited to T-050/design and the narrowly required member-presence API data; do not take unrelated backlog work.

**Files:** `frontend/src/design/design_fidelity.spec.ts`; `frontend/src/design/avatar_color.ts`; `frontend/src/design/shell.css`; `frontend/src/design/responsive_shell.css`; `frontend/src/design/voice.css`; `frontend/src/design/voice_participant_screens.css`; `frontend/src/design/voice_viewer_reference.css`; `frontend/src/style.css`; `frontend/src/conversation/ConversationPane.vue`; `frontend/src/workspace/WorkspaceApp.vue`; `frontend/src/workspace/WorkspaceMembersPanel.vue`; `frontend/src/workspace/WorkspaceHeaderActions.vue`; `frontend/src/workspace/member_presence.ts`; `frontend/src/identity/profile_client.ts`; `frontend/src/identity/guild_presence.ts`; `frontend/src/voice/VoiceParticipantVolumes.vue`; `frontend/src/voice/ScreenViewer.vue`; `frontend/src/voice/find_participant_screen.ts`; `frontend/src/voice/screen_video_quality.ts`; `frontend/src/voice/screen_viewer_controller.ts`; `frontend/src/voice/voice_room_copy.ts`; `frontend/src/voice/participant_screen_actions.spec.ts`; `frontend/src/voice/screen_viewer_reference.spec.ts`; `frontend/src/voice/voice_room_presentation.spec.ts`; `frontend/src/identity/profile_client.spec.ts`; `backend/internal/realtime/event_hub/hub.go`; `backend/internal/realtime/connect_session/http_handler.go`; `backend/internal/identity/list_members/service.go`; `backend/internal/identity/list_members/api/http_handler.go`; `backend/cmd/api/main.go`; `backend/cmd/api/realtime_routes.go`; `backend/cmd/api/member_routes.go`; `backend/cmd/api/profile_admin_routes.go`; `contracts/openapi.yaml`; `docs/superpowers/plans/2026-09-24-guildchat-design-fidelity.md`; `TODO.md`.

### Task 1 — Capture failing design checks

- [x] Assert the prescribed 1440/1280/1024 shell geometry and drawer behavior rather than a permanent 208px member column.
- [x] Assert keyboard-visible header actions and the mobile persistent VoiceDock.
- [x] Assert that the member pane uses authenticated guild profiles while only live voice participants receive speaking/mute state.
- [x] Assert participant-card anatomy/144px minimum and selected-stream fullscreen controls.
- [x] Run `npm test -- design_fidelity.spec.ts`; all four initial checks failed against the existing frontend before changes.

### Task 2 — Restore the reference voice surfaces

- [x] Render self and connected peers as stable participant cards, 160px minimum width / 144px minimum height, with explicit speaking/muted state and the existing per-peer volume control.
- [x] Drive the local card's speaking outline/status from LiveKit `ActiveSpeakersChanged`, append `· вы` to its display name, and remove the separate visible self badge; cover the local event, no-track notification, lifecycle cleanup, and presentation with tests.
- [x] Keep one selected remote stream, contain sizing, and both browser fullscreen and app-area expansion; the viewer return action clears only the stream selection and leaves voice active.
- [x] Remove layout rules that compress or hide participants and ensure the 20-person list scrolls internally.
- [x] Run voice presentation tests and the focused design test.
- [x] Re-run the full frontend suite after the local-speaker match: 71 files / 215 tests pass; `npm run build` (`vue-tsc --noEmit` + Vite build) passes.

### Task 3 — Make workspace regions match the responsive contract

- [x] Keep 312/768/312 at 1440+, 264/remaining/240 at 1280–1439, and 256px navigation plus an on-demand 320px member drawer at 1024–1279.
- [x] Below 1024px show one main region, controlled navigation/member drawers, and a persistent bottom VoiceDock; do not stack the whole navigation and roster above/below the channel.
- [x] Show real guild members in the right pane outside DM; identify live voice status only from LiveKit participants, and explain when room membership is unavailable until joining.
- [x] Preserve no-aside DM/settings behavior and existing ACL/API/media actions.
- [x] Match the reference single-guild sidebar identity (`Моя гильдия`, G mark) without adding guild discovery.
- [x] Run focused tests, all frontend tests, typecheck/build, and `git diff --check`; inspect changed-file line counts and identify manual visual checks below.

**Manual visual acceptance still open:** The supplied PNGs were inspected as visual references. On 2026-09-24, the authenticated production Chrome tab at a 1256 × 1214 CSS viewport / DPR 1.5 showed the selected `game-audio-poc` disconnected card and the older `V / Voice Platform` sidebar. A fresh GET of the production root returned HTTP 200 and still references `/assets/index-BBtWDZ7p.js` and `/assets/index-B8Y8BEEs.css`. Clean commit `4f5a78a` was independently built in a detached worktree: 70 test files / 200 tests passed, and its `dist/index.html` references `/assets/index-BPuFEA1J.js` and `/assets/index-Bw5w8H_8.css`. This is an artifact mismatch, not just an unrefreshed tab. Candidate commit `4f5a78a` is pushed to `codex/voice-platform-foundation`, but is not merged to `master` or deployed. A connected-room screenshot is not available because the production client is not joined. After the candidate is deployed for QA, compare 1440/1280/1024 CSS px and 125%/150% browser zoom, including live roster, mic/speaking states, and expanded stream, before closing T-050. The new presence groups are backed by active authenticated realtime connections; `unknown` remains separate from offline.

The C-31/C-32 selected-viewer composition and its native tests reflect the supplied `voice-1440.png`/`stream-1440.png` references locally. The current candidate is commit `4f5a78a`; production remains on the previously published release `868092a`. A connected-room production screenshot remains necessary for visual acceptance.

### Task 4 — Match voice-screen composition and exact member-panel states

- [x] Add failing frontend design tests that voice rooms use the full main column at 1440/1280 and that the member panel is an on-demand overlay while chat retains its right column.
- [x] Add failing tests for three truthful roster groups (`online`, `offline`, `unknown`), with unknown never placed under offline and no Away group.
- [x] Make the voice header's members control available at wide widths; show only members actually connected to that room in its voice-scoped panel.
- [x] Run the focused design tests, all frontend tests, typecheck, and build.
- [x] Match C-31/C-32 selected-stream composition: stable room header identifies the publisher; canvas has viewing/publisher overlays; the rail uses participant avatar/name/audio/selected metadata; quality stays honest when the publisher provides no target or FPS measurement; returning to participants preserves voice.
- [x] Keep video mounted while its viewer panel is visually hidden so a participant-card action can attach the chosen track before showing the viewer.
- [x] Reflow quality, diagnostic, audio, and app-window controls into a vertical toolbar at widths up to 1100 CSS px; regression-covered for zoomed/narrow layouts.
- [x] Match stream-rail subtitles to the reference selection states (`Вы смотрите` / `Нажмите, чтобы смотреть`) while retaining an accessible audio-track description.
- [x] Add the C-33 compact diagnostics badge and 288px details panel; remote connection/FPS values remain explicitly unknown without fresh measurements.
- [x] Preserve C-31 `ended` state when the selected publisher disappears; keep remaining streams unselected until an explicit choice, and keep the room observer alive after returning to participants.
- [x] Show a truthful waiting-frame overlay until the selected stream yields decoded video data; reset it on publisher/track changes.
- [x] Implement the C-32 owner preview from the existing local LiveKit screen publication; react to `LocalTrackPublished`/`LocalTrackUnpublished`, label it `Ваш экран`, mute its video, and never subscribe to or play the owner's screen audio locally.
- [x] Show an accessible right-edge hint only while additional stream-rail cards remain to the right; clear the hint at the end of horizontal scrolling.
- [x] Match the stream-view footer's secondary copy and two-line hierarchy while retaining the return-to-participants action.

### Task 5 — Supply truthful guild presence

- [x] Add failing Go tests for per-account active WebSocket counting across multiple tabs and for online/offline/unknown mapping in the authenticated `/members` response.
- [x] Track each authenticated realtime connection in the shared in-process event hub; decrement only when that specific connection closes.
- [x] Add the `presence` enum to guild-member REST models and OpenAPI, returning `unknown` only when presence tracking is unavailable.
- [x] Parse and refresh presence in the web roster without deriving it from role, voice membership, or avatar color.
- [x] Run focused Go tests, frontend tests/build, `scripts/verify-contracts.ps1`, and `git diff --check`.

### Task 6 — Verify the real rendered result and release only design changes

- [ ] Capture the authenticated app at 1440/1280/1024 CSS px and 125%/150% browser zoom; compare channel grid, roster, mic/speaking indicators, and the expanded stream canvas against the supplied reference.
- [ ] Correct any measured layout/token mismatch and rerun the native tests/build.
- [x] Publish the earlier validated design slice through GitVerse Actions. Release commit `868092a` passed run `#1634609`; its refreshed production page showed the disconnected-room card. Do not include unrelated dirty-worktree tasks in any release.
- [ ] After visual acceptance, publish the completed design-only changes and verify Chrome loads the exact assets produced by the final local build.
- [ ] Update T-050/TODO and this plan only with observed evidence; keep hardware Windows/macOS POC runs with the owner.

**Stop condition:** T-050 is not closed until the focused code checks pass, the production design build is visible in Chrome, and the required screenshot/zoom review has evidence. Physical media POC remains out of this packet.
