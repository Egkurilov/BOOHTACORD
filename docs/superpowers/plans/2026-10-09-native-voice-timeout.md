# Native voice timeout implementation plan

Goal: bind ADR-023's current-state/set/lift voice restriction to an actual native administrator dialog.
Architecture: `split_first`, T-051/T-050 native UI leaf; approved #97 extends voice kick. Typed feature `features/admin/voice_timeout/{model,api,facade}.dart` owns only existing scoped HTTP contracts. `screens/admin_voice_timeout/{controller,dialog,surface,form,status,actions}.dart` owns one moderation dialog lifecycle. Existing admin UI wiring belongs to root integration; media/VoiceJoin/TEXT/DM untouched.
Tech stack: Flutter/Dart, existing ApiTransport and ApiClient; base37ced0a7936fdab62d0a9e4d2ff5113a09f13202.
Ratchet: target100/hard120 lines, target8/hard16 files; stop at evidence plus clean local commit.

- [x] Add `test/admin_voice_timeout/{model_test,api_test,scope_test}.dart`; demonstrate red missing types/facade. Assert exact GET/PUT/DELETE paths, secure cookie+Origin, bounded reasons/UTC future<=24h, strict active/inactive/pending parsing and session/deployment stale cancellation.
- [x] Implement immutable `VoiceTimeoutState.parse`, `VoiceTimeoutInput` validation and `AdminVoiceTimeoutApi`; add facade to exact `services/api_client.dart`. Native requests use transport.run; PUT expects202, GET/DELETE200; pending never means physical completion.
- [x] Add actual widget tests for read-before-mutate, reason/duration, confirmation/cancel/lift, server denial/retry, pending truthful label, stale target/disposal and compact safe-area/focus behavior; run red before screen implementation.
- [x] Implement `showAdminVoiceTimeout(context, api: api, accountId: id, displayName: name, scopeChanges: state)` and actual `AdminVoiceTimeoutDialog`. Scope controller captures ticket+server revision; changing target recreates controller; result after disposal or scope loss is ignored. Mutations require loaded state and confirmation, never autojoin/unmute.
- [x] Run `flutter test --no-pub test/admin_voice_timeout`, full Flutter suite, `flutter analyze --no-pub --no-fatal-infos`, `python -m tools.ci.native.contracts`. Record observed acceptance and physical QA NOT_RUN in evidence; inspect sizes/status, stage exact files, local commit.

Root wiring: import `screens/admin_voice_timeout/dialog.dart`; use its show function with existing ApiClient/account ID/display name. No AppState or UI import under feature leaf; no production mutations or release claim here.
