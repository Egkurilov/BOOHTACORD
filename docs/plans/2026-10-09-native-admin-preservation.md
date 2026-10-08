# Native admin preservation before timeout/accessibility

Packet: split_first; route clients/flutter/lib/src/screens/admin_screen.dart -> admin_ui child capabilities. Preserve existing callbacks, draft/conflict handling, topology revision checks, media refresh timers and lifecycle/super ordering.

Baseline: 39 native tests PASS across admin API, permissions, panel geometry, readiness and topology before source movement. Retain these tests as first-pass behavior checks.

1. Physically move fields, typed contracts, lifecycle and handlers into native child capabilities. The facade and aggregate bindings contain exports only.
2. Extract actual widget subtrees with typed captured arguments. No duplicated alternate admin implementation or part-file dump.
3. Run scoped analyzer, the same 39 tests and native dependency verification. All new production Dart files <=120 lines; child leaf <=16 direct production files. Correct imports/promotions introduced by physical movement without changing behavior.
4. Add scoped voice timeout UI and cross-cutting accessibility in separate packets after the preserved baseline is green.

Stop condition for this packet: behavior checks green and physical files within ratchet. Physical screen-reader/device QA remains a separate acceptance task.
