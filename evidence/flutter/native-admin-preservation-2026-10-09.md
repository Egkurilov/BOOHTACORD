# Native admin physical preservation

Route: screens/admin_screen.dart -> screens/admin_ui child capabilities. Packet split_first; no new product behavior in this packet.

The original 1897-line State implementation is now an export facade. All 49 existing methods, account drafts/conflicts, topology revision callbacks, section selection, audit state, media refresh lifecycle, focus nodes and password-reset link behavior were physically retained in typed handlers. State mutation and super init/dispose order remain explicit. Widget subtrees use typed captured arguments; no part-file dump or static replacement UI.

Validation on the named final source:

- Same five nearest native suites before and after conversion: 39 PASS each.
- Scoped Dart analyzer: no issues.
- Native import/dependency verifier: 1275 files PASS.
- 81 production Dart files; maximum 107 lines; maximum 3 direct production files per leaf.
- Generated plugin registrant differences were line-ending only and excluded.

These unit/widget checks prove source preservation for the covered paths. Physical screen-reader/IME/Windows/iOS runtime acceptance is not claimed. Timeout binding and accessibility are subsequent separate packets.
