# Workspace UI leaf conversion implementation plan

**Goal:** Physically decompose the 9,290-line workspace widget library so #270 retry/stale UI and subsequent owned UI changes can be wired through bounded leaves.
**Architecture:** Preserve 79 existing workspace widget tests as baseline. Move each public component and its paired state into a capability library, preserve listener/dispose callbacks and exact source selection/media paths. Extract oversized rendering subtrees into typed component interfaces and lifecycle handlers by trigger. Keep legacy screen entrypoint as a thin import/export facade, not a broad part dump.
**Tech Stack:** Flutter/Dart; installed Flutter3.47.5; AST inventory is external diagnostic only.

Packet mode=split_first/conversion; original baseline tests=79 PASS; route=workspace UI native composition; hard120 applies every owned production file; each capability max16 production files. Native edges=workspace_screen.dart→prejoin, channel navigation, conversation, direct conversation, search panel, voice room/viewer, audio settings, members/profile and message edit. Conversion is NOT PASS while original executable aggregate remains or any moved leaf exceeds hard120. Unknown callback behavior stays identical and existing runtime tests must pass.

- [x] Extract prejoin card/roster/member-row into typed child leaves; add stale/unavailable retry semantics and focused UI tests while preserving manual Join/listen actions.
- [x] Separate workspace shell navigation/drawer/keyboard/window lifecycle; preserve observers, event ordering and selection invalidation.
- [x] Separate channel/category navigation and authenticated roster rendering; preserve ACL-derived selection and stable keys.
- [x] Separate TEXT and DM conversation send/history/composer/draft triggers and message row rendering; preserve IDs/retry/reply/edit/read behaviors.
- [x] Separate search panel/context lifecycle from conversations; preserve panel layout/focus/selection restoration and pagination.
- [x] Separate voice room, participant controls, viewer/fullscreen/mini-player and source selection; preserve existing media ownership and cleanup.
- [x] Separate audio settings, dock, members/profile popover and edit dialog with native interfaces. Do not change unknown actions.
- [x] Make original screen entrypoint <=120 lines of composition/export; review all owned leaf sizes/counts and resolve every executable aggregate.
- [x] Run scoped Flutter analyze and the 79 baseline workspace tests plus focused new roster UI tests after each coherent extraction; broader tests only if native interface changes require it.
- [x] Commit conversion separately from validated roster-state/setup packets once all topology and behavior checks pass.
