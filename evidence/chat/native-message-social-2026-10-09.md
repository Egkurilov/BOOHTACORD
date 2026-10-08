# Native message reactions and TEXT pins — #96

Date: 2026-10-09. Source base: `362f1b5ee446fecdc77f245bcbaa5e06ca8b7cff`.
Packet: `split_first`; Flutter bindings for approved ADR-024 server/Web contracts.
Backend/Web evidence: [message-social-2026-10-09.md](message-social-2026-10-09.md).
No migration, dependency, media transport or production mutation in this packet.

## Behavior and scope

- Actual common TEXT message rows and private DM bubbles expose the approved six
  reactions: 👍 ❤️ 😂 🎉 👀 ✅. Explicit PUT/DELETE sets desired membership; counts
  and mine flags are read again from the current authorized server scope.
- Reaction reads batch at most 100 unique message IDs per TEXT/DM scope. No reactor
  identity list, bodies or client-assumed permission grants are accepted.
- Only common TEXT exposes pin controls, using the server's `can_pin` and
  `can_manage` decisions. Pin/unpin uses administrator TEXT routes. DM has no pin UI.
- The real search header opens a bounded, cursor-paginated TEXT pins panel. Opening
  a pin uses the existing protected search-context API and original message ID.
  The widget test observes full original text and revision 3 returned by that API,
  rather than treating the short preview as message content.
- Native realtime advertises `message_social_v1`; the three supported social hints
  require exactly two validated IDs. Full ready/resync recovery re-reads metadata.
  This preserves the existing native refresh/resync mechanism; no synthetic replay
  cursor or new account subscription model was introduced.
- Controllers and batch work capture session ticket plus deployment revision,
  reject stale completion, isolate transports/scopes, and unsubscribe on disposal.
- Loading, retry, current count/mine state and mutation busy state are visible;
  inaccessible metadata clears on read failure. Emoji targets are at least 44×44.
- Existing sends, deletion, edits, attachments, replies and SYSTEM_WELCOME rows
  remain on their original paths. Mention-label extraction preserves its rendering.

## Native acceptance

Environment: Windows, Flutter 3.47.5 / Dart 3.13.4, project-owned Flutter test runner.
HTTP/widget fixtures contain synthetic IDs and no production message data.

| Check | Result |
| --- | --- |
| Baseline `flutter test --no-pub test/workspace_screen_test.dart` | PASS: 79 tests before bindings |
| Focused `flutter test --no-pub test/message_social` | PASS: 15 tests in 9 responsibility-focused files |
| Complete `flutter test --no-pub --concurrency=4 --reporter=json` | PASS: final 928 tests; 1 pre-existing skip; success=true, 93.677s |
| `flutter analyze --no-pub --no-fatal-infos` | PASS: no errors/warnings; 57 pre-existing info diagnostics outside new packet leaves |
| Canonical `python -m tools.ci.native.contracts` | PASS: 260 tooling tests, 1 pre-existing tooling skip; 19 contracts, 108 public/3 private endpoints; Dart local import/UI boundaries 1208 files; 466 document references |

The skipped Flutter test is `native Flutter SDK and frame observation survive real
relay and Tempo`; it requires the existing real-relay/Tempo integration environment.
Ignored `.out/native-message-social-tests.jsonl` records the complete final runner
events; `.out/native-message-social-contracts.log` records the native contract check.
All 29 touched Dart source/test files are at most 117 actual lines; the largest
production leaf has 3 files. The focused test leaf has 9 files, below the hard 16.

Focused cases cover exact six private mutations, 100-ID batching, account/server
boundary cancellation, transport separation, hint rejection/disposal, actual TEXT
row PUT/DELETE, DM exclusion of pins, stale response after replacing conversation,
admin pin PUT and unpin DELETE, member pin denial, ACL recovery, cursor parsing,
literal preview rendering and original authorized search-context navigation.

The initial focused API and row tests were red before their implementation/binding.
One additional pin-control test initially had an incorrect expected URL prefix;
correcting that fixture to the existing `/api/v1/admin/text-channels/...` contract
passed without weakening a source or server check.

## Limits and QA handoff

Device/released-artifact acceptance: NOT_RUN. This packet's actual Flutter widget
and source checks do not claim a Windows/Android/macOS shipped binary was exercised.
No deploy, release build or GitHub issue mutation was performed by this packet.
Server real PostgreSQL/live WebSocket privacy and Chromium evidence remains in the
linked backend/Web record. No PostgreSQL tunnel was used or held by native work.

Follow-up QA: on each supported shipped client, two TEXT users and two DM participants
should toggle all six emoji while another client observes count/mine changes; retry
after reconnect and switching account/deployment; verify administrator pin/unpin,
ordinary-member read-only pins, original-message jump, pagination, deletion cleanup
and loss of TEXT visibility. A third user/admin must not see foreign DM metadata.
