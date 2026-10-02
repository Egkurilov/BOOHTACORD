# Comparable state rebuild sample

Use the same Flutter SDK and host for the before/after revisions. Copy
`benchmark_test.dart` into the selected client's `test` directory under a
temporary name, run `flutter test test/reorganization_benchmark_test.dart
--reporter expanded`, and remove that temporary test. Retain the
`STATE_BENCHMARK` JSON with source SHA and host/toolchain details in evidence.

The scenario runs 10 warmups followed by 100 completed roster refreshes in an
empty authenticated workspace at 1440×900. It counts actual AppState notifications
and dirty-widget rebuild callbacks, and measures CPU wall time of each test
renderer pump. Run three repetitions; this is a diagnostic comparison, not a
timing assertion in CI. No live accounts, network requests or media are used.

This measures debug framework work. Physical GPU frame time, jank and connected
voice/stream behavior still require a native profile run on the target device.
