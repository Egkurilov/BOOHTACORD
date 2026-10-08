# Bounded message reactions and TEXT pins implementation plan

**Goal:** Deliver the owner's approved six reactions in TEXT and two-party DM, and administrator pins in common TEXT channels, preserving privacy and existing message/media lifecycle.

**Architecture:** Independent change/list reaction and change/list pin capabilities with current-account, conversation and live-message ACL at SQL effect boundaries. Explicit PUT means present and DELETE means absent; duplicate requests are safe. PostgreSQL soft-delete triggers clear reaction/pin metadata atomically with message deletion. ID-only realtime hints invalidate reads, with current ACL rechecked on replay. Browser controls remain inside actual conversation/message components.

**Tech Stack:** Go/pgx/PostgreSQL, secure session/Origin middleware, existing event journal/WebSocket, Vue/TypeScript/Pinia.

Operating brief: split_first; scoped leaves `chat/change_message_reaction`, `chat/list_message_reactions`, `chat/change_text_pin`, `chat/list_text_pins`, `app/message_social_routes`, `conversation/reactions`, `conversation/pins`. Native edges: runtime route registration; MessageItem/TextConversation and existing message context; exact journal hint validator/authorization and Web event parser/dispatcher. Target100/hard120 lines; production/test leaf target8/hard16. Preserve existing baseline before any component extraction. Reserve migration0052 and ADR024; root coordinates0051.

Owner-confirmed scope: 👍 ❤️ 😂 🎉 👀 ✅; reactions in TEXT/DM; idempotent explicit PUT/DELETE; administrator-managed common TEXT pins, opening the original message. No DM pins, activity feed, group DM, release blocker or generic outbox.

- [x] Document ADR024 and exact public routes, bounded read payloads and ID-only hints.
- [x] Add focused red validation/idempotency/privacy tests before server code; add0052 reaction/pin tables, uniqueness, soft-delete cleanup and migration fingerprints.
- [x] Implement independent reaction write/read SQL leaves. Bind actor, conversation and message; lock actor/message at write boundary; prevent blocked/deleted/archived/foreign-DM operations. Batch read at most100 IDs, no reactor identities.
- [x] Implement TEXT pin write/read leaves. Current administrator only; live common TEXT only; bounded cursor paging; denied DM/admin DM access. Preserve message ID and history.
- [x] Register typed APIs through existing cookie and CSRF/Origin gates. Extend ID-only metadata hint validator/replay authorization and targeted DM publication; no user/message/body metadata logging.
- [x] Baseline and preserve MessageItem/TextConversation behavior; split mixed/over-hard source before adding actual reaction controls and pin panel, original message navigation, loading/error/retry/stale guards, unmount/logout cleanup.
- [x] Add exact OpenAPI/event schemas and native contract/parity tests; no weakening existing ACL predicates.
- [x] Run meaningful isolated PostgreSQL idempotency, concurrent/deletion/block/archive/replay and DM outsider/admin privacy matrix; coordinate exclusive DB with root.
- [x] Run native nearest Go tests/vet, Web tests/build/vue-tsc and actual Chromium component flows. Source/widget acceptance does not replace device or deployed authenticated end-to-end QA.
- [x] Record truthful evidence, inspect sizes/status and commit exact source locally. Parent owns integration/issue mutations; Flutter binding follows its concurrent workspace conversion and typed API handoff.
