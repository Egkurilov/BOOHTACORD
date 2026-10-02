# BOOHTACORD background plugin patches

The local source is based on flutter_background 1.3.1. [UPSTREAM.json](UPSTREAM.json)
records the verified pub.dev archive SHA-256, retained MIT license and differences.

`android/build.gradle` detects AGP built-in Kotlin before conditionally applying
the legacy Kotlin plugin. Compiler target configuration supports both modes.
The README and analyzer options are local documentation/lint adjustments.
No separate background application or product capability is introduced.

Verification: `bash tools/verify/android_kotlin/verify_android_kotlin_modes.sh`,
the shared Android build command, and the app/vendor native test gate. Device
MediaProjection/background acceptance remains separate from compilation.

Remove the local override only after upstream supports both Kotlin modes and
the same native build and physical background/screen-sharing checks pass.
