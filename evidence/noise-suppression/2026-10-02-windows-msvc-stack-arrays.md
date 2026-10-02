# Windows/MSVC RNNoise portability gate

```yaml
status: IN_PROGRESS
gate: Flutter Windows Release build with opt-in native RNNoise compiled
failed_run: https://github.com/Egkurilov/BOOHTACORD/actions/runs/36991122856
failed_revision: 1c2bc0a
failure: MSVC C2057/C2466/C2133 for variable-length scratch arrays in RNNoise pitch.c and celt_lpc.c
fix: use bounded-per-call stack allocation through _alloca on MSVC; retain original VLA behavior on other compilers
local_python_audio_tests: PASS, 6 tests
local_clang_no_vla_syntax: PASS, -Werror=vla with stack-allocation compatibility path enabled
local_native_capture_processor_harness: PASS, release-optimized build and frame processing assertions
hosted_windows_release_after_fix: NOT_RUN
hardware_acoustic_acceptance: NOT_RUN
release_readiness: NO_GO until hosted Windows build and physical audio acceptance
```

The portable shim replaces only automatic scratch-array declarations and does
not add heap work to the capture callback. The vendored source checksums bind
the two local portability edits. The next gate is to run the Flutter Windows CI
workflow against the fixed commit; the build alone does not establish acoustic
quality, real-device audio routing, or release readiness.
