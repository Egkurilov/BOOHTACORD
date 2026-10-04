# Design V2 channel tree fidelity plan

Execute inline; `small_direct`, T-050, leaf `channel/ChannelNavigation` presentation.

**Goal:** Match channel-tree controls, labels, icons and connected voice rows to the live HTML without changing topology actions or voice ownership.

**Architecture:** Keep `ChannelNavigation.vue` emits, permission resolvers, disclosure and roster inputs. Replace decorative text icons with handoff SVG and add a scoped CSS leaf. Set header/row rhythm using source sizes, retaining the real speaking indicator and semantic audio state.

**Files:** `clients/web/src/channel/ChannelNavigation.vue`, `clients/web/src/design/design_v2_channel_tree.css`, `clients/web/src/style.css`; if needed adjust the preceding desktop tab margin by 1 px to align the channel section start.

- [x] Measure current R01/R14 versus immutable HTML; preserve before screenshots and computed geometry.
- [x] Replace text plus/hash glyphs with supplied SVG; keep all aria labels and event handlers.
- [x] Apply source 36 px desktop controls/rows, 44 px mobile controls/rows, section margins, 18 px channel icons and 600 unread labels. Keep selected/connected data intact.
- [x] Apply source 32/36 px voice rows, 22 px avatars, 9/600 initials and real screen-sharing badge. Preserve measured speaking/audio state.
- [x] Verify category collapse/reopen, permitted create/cancel and focus return, navigation and connected voice store. Run resolver, disclosure, badge and voice-presence tests, then build.
- [x] Compare captures and source bounds, inspect diff and file sizes, record evidence, commit.

All changed production files must remain below 120 lines. The source has separate decorative and real states; do not fabricate roster/audio values to match PNG. Full goal remains open.
