# Design V2 message avatar tone plan

Execute inline as a separate `small_direct` packet, leaf `conversation/avatar_fallback` (T-050).

**Goal:** Match fallback initials to the handoff palette in real channel and DM messages.

**Architecture:** `MessageItem.vue` uses `avatar_fallback.ts`; other identity surfaces already use the paired V2 tones. Keep the existing hash and backgrounds; correct only four foreground values. Private uploaded avatars retain the same image/error lifecycle.

**Tech stack:** Vue SSR, Vitest, native Playwright visual probe.

- [x] Add and run a failing table test in `avatar_fallback.spec.ts`: the four colored palette entries must render their matching handoff foreground in text and DM rows.
- [x] In `avatar_fallback.ts`, change white foregrounds to `#a5f2f0`, `#ffd5a8`, `#e3dcff`, `#e9cbff` for existing blue/green/violet/orange backgrounds; retain gray `#f4f5fa`.
- [x] Run `npm test -- src/conversation/avatar_fallback.spec.ts src/design/avatar_color.spec.ts`; preserve the uploaded-avatar behavior assertion.
- [x] Capture real chat R01/R02/R03 and DM R28 with the existing identical fixture; compare before/after against immutable references and inspect changed avatar pixels.
- [x] Record exact files, checks, immutable reference hashes and remaining differences; commit only this packet.

Production file 15 lines, test below 120 lines. No API, message actions or media state changes. Stop when nearest tests and the four visual captures pass without regression; full-goal 1:1 is still open.
