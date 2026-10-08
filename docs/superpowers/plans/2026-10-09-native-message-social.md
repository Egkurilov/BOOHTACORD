# Native reactions and TEXT pins

Operating brief: split_first; source base362f1b5ee446fecdc77f245bcbaa5e06ca8b7cff; preserve converted message_row/direct_conversation, existing search context and native realtime refresh/resync. Leaves conversation/reactions, conversation/pins, realtime/social_hints and screens/workspace_ui/message_social, text_pins. Pure feature leaves depend on HTTP/session contracts, not AppState. UI binds actual common TEXT and DM rows. Target100/hard120 lines, target8/hard16 production/direct tests. No media/dependency/schema changes; no invented native cursor replay.

- [x] Focused red API/private/session tests; baseline existing workspace behavior.
- [x] Typed bounded reads and explicit desired-state PUT/DELETE over existing secure scoped transport.
- [x] Per-transport reaction batches; strict ID-only hint invalidation and ready/resync recovery; scoped unsubscribe and stale-result guards.
- [x] Actual TEXT/DM reactions, counts/mine, loading/error/retry; administrator TEXT pin/unpin/list and original message context navigation.
- [x] Actual widget tests, nearest/full native tests/analyze, contract dependency check; truthful evidence and exact local commit.

Stop condition: source/native acceptance passed, evidence says which device/deployed checks remain, clean local commit delivered to parent. No push/merge/issues mutations.
