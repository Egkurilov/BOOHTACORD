# Design V2 guild member roster fidelity plan

Execute inline; `small_direct`, T-050, leaf `workspace/GuildPresenceGroup` presentation.

**Goal:** Match the existing guild member list to the R01 live HTML without changing presence data or profile actions.

**Architecture:** Add a CSS leaf scoped to `.members-guild-roster`, imported by the native `style.css`. Preserve the voice roster, unknown presence, pagination and profile/DM handlers. Read `GuildPresenceGroup.vue`, `WorkspaceMembersPanel.vue`, `shell.css` and their exact CSS overrides.

**Tech stack:** Vue, CSS, native Playwright probes and Vitest presence/focus tests.

- [x] Capture current R01 and the immutable HTML with the same local Inter; record header, row, avatar, name, status and second-group geometry.
- [x] Add `design/design_v2_member_roster.css`: 16 px uppercase group labels, 28 px between groups, 52 px rows with 8 px padding and 4 px gaps, 13/600 avatar initials, 500 names, 12/16 status, content-box online dot. Hide only the redundant decorative offline dot.
- [x] Compare measured bounds/styles before and after; preserve mobile targets at least 44 px and unknown status distinction.
- [x] Capture R01 and R18 against unchanged PNGs. If corrected row placement moves the anchored profile, calibrate only its visual offset to the R18 handoff.
- [x] Run nearest presence/focus tests, actual desktop/mobile profile interactions and build. Record exact metrics and limitations, inspect file sizes, commit.

Stop when roster geometry matches source, targeted raster errors improve and profile/focus/DM behavior remains intact. No claim that source HTML and supplied PNG render identically. New CSS below 120 lines; no contract changes.
