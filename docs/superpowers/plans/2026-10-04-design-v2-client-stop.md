# Major client surfaces — final authorized packet

> Execute inline under the user's instruction: finish the largest obvious client sections, then stop. Do not start admin work or an exhaustive remaining polish pass.

**Goal:** Finish visible responsive settings, stream quality selection and protected image viewing, verify and publish them, then pause the original full design goal.

**Architecture:** Three sequential small_direct leaves, followed by review_gate and branch_sync. Change presentation on existing stateful Vue controls; preserve media, authorization and attachment lifecycle.

**Tech Stack:** Vue, CSS, Vitest, native browser probes and raw HTML/PNG comparisons.

## Operating brief

T-050 UI depends on T-020/T-022/T-040; exact edges are WorkspaceMain -> AudioSettings/ProfileSettings, ScreenShareSetupDialog -> ScreenShareQualityOptions, MessageItem -> PublishedAttachmentCard -> ProtectedImageViewer -> useProtectedImagePreview.
Ratchets: 100 target/120 hard source lines, 8 target/16 hard production files per leaf. Baseline 1187e78b; scoped captures saved in external design-v2-client-finish-2026-10-04. No contracts/backlog changes. Stop condition is the user's newly limited scope, not a claim that all original design requirements are complete.

## 1. Responsive personal settings

Files: design_v2_profile_presentation.css, design_v2_audio_presentation.css; focused layout specs.

- [ ] Add failing assertions for responsive content padding and mobile profile save spacing.
- [ ] Keep desktop content 880px: outer max-width 944px with 32px padding; tablet max-width 928px with 24px padding; mobile threshold 1023px, 16px horizontal padding.
- [ ] Profile tabs: desktop 45px, gap 8px, margin 24px; mobile gap 0, margin 20px. Mobile profile savebar margin-top 4px accounts for form grid gap 20px and produces the reference 24px separation.
- [ ] Capture desktop/tablet/mobile; verify profile mutation/security navigation and audio actions remain operational.

## 2. Stream quality presentation

Files: design_v2_screen_quality.css; screen_share_setup_dialog.spec.ts; browser verification helper.

- [ ] Save failing source-geometry comparison for R20/R30.
- [ ] Use segmented padding/gap 4px; options min-height 36px desktop/40px mobile with 44px mobile hit area. Legend margin-bottom 8px, group gap 20px, warning margin 0.
- [ ] Align heading/body and footer: desktop header min-height 120px/padding-top 28px; mobile retains 126px/36px, no bottom border; footer buttons padding 14px, 14px text, mobile equal widths.
- [ ] Verify genuine radio updates, cancellation/focus, apply via current sender store, and preservation of the selected MediaStream.

## 3. Protected image viewer

Files: ProtectedImageViewer.vue, protected_image_preview/viewer.css, style.css, design_v2_contextual_overlays.css, protected_image_viewer.spec.ts.

- [ ] Add failing SVG/toolbar regression; save source geometry before changes.
- [ ] Replace decorative Unicode glyphs with handoff file/download SVG paths. Keep protected blob URL, filename/download attributes and existing handlers.
- [ ] Set one rgba(3,5,9,.94) surface with transparent native backdrop; header 64/56px, gap 12px, proper download control, close 36/44px; filename truncates within flex space.
- [ ] Restore image container padding 48/12px, width 980px constrained to available area and height, footer padding 16px. Preserve object-fit contain and all loading/retry/unavailable behavior.
- [ ] Verify mobile touch targets, keyboard Escape/close focus, actual protected download and blob revocation. Preserve existing preview lifecycle tests.

## 4. Review and stop

- [ ] Full Web tests and production build, git diff check; no physical-media claims.
- [ ] Fresh 29-state actual/HTML/immutable PNG comparison, raw diff, hashes, focused report and updated audit.
- [ ] Inspect exact changed sizes/status, commit explicitly, synchronize current master, push both branches, record observed CI state.
- [ ] Pause goal at user's request. Report implemented client sections, evidence and remaining admin/fine fidelity scope without claiming full 1:1.
