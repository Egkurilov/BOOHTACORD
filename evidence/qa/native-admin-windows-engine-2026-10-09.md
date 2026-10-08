# Native admin Windows-engine verification — #197 / #97

Date: 2026-10-09. Route: review_gate. Status: PASS for this bounded engine packet.
Exact source: `b7a0582cc0a4d829d40665e0654a2eb097fd214f`. Production sources were unchanged by this packet.
Structured output: [native-admin-windows-engine-2026-10-09.json](native-admin-windows-engine-2026-10-09.json).

## Execution boundary

- Flutter3.47.5 / Dart3.13.4, Windows x64 debug embedder, Impeller OpenGLESSDF,
  actual devicePixelRatio1.5. All146 shared pinned dependency versions matched the
  tracked Flutter lock. Local Inter font was copied from tracked client assets.
- Ignored owned host: `.out/native-admin-engine/host`, using the real AppState,
  AdminScreen, native timeout launcher/form and shared confirmation route imported
  from this repository. Synthetic typed account/API only; no real backend or media.
- The generated host disables its first-frame Show callback, since the production
  bootstrap calls Show even after Start-Process Hidden. Hidden launch, own HWND resize
  through window_manager, visibility false before every case and at exit; teardown
  destroys only the owned host. No global SendInput, foreground operation or user app.
- Short owned drive mapped the ignored parent so MSVC paths stayed below its limit;
  the host copied existing production clipboard CMake include/warning adjustments.
  Ignored package URIs were normalized for that drive. No plugin/runtime source change.
- Normal WidgetsFlutterBinding and native PlatformDispatcher metrics; no TestFlutterView
  metric override. LiveWidgetController pointer events and synthesized KeyData events
  through the actual PlatformDispatcher callback drive the real framework components.
- Text scale1/1.3/2, safe padding32/34, IME inset300 and reduced motion are simulated
  MediaQuery inputs. They are not physical Windows settings or OS keyboard acceptance.

## Assertions observed in each of nine cases

- Real own client dimensions390/600/1440 ×900, allowing native rounding below1dp.
- Compact launch or desktop popup path, exactly one scoped GET for the synthetic target.
- Existing active timeout renders grant/lift/refresh/close; nested grant confirmation
  renders cancel/confirm. All six targets are48dp; each action is scroll-reachable
  above the simulated keyboard. Desktop launcher44dp, compact launcher48dp.
- Synthesized Escape dismisses the nested confirmation first, then the timeout route,
  and restores the real initiating FocusNode. Reduced-motion route duration is zero.
- Zero timeout writes, no voice channel/Room, no framework errors; no automatic Join.
- Actual RepaintBoundary raster readback390/600/1440 ×600, non-null raw RGBA buffers
  of936000/1440000/3456000 bytes. Pixels/images were not retained or committed.

| Native logical client | Simulated text scale | Actual branch | Launch dp | Six timeout targets dp | Result |
| --- | --- | --- | --- | --- | --- |
| 390.000 × 900 | 1.0 | compact | 48 | 48 | PASS |
| 390.000 × 900 | 1.3 | compact | 48 | 48 | PASS |
| 390.000 × 900 | 2.0 | compact | 48 | 48 | PASS |
| 600.000 × 900 | 1.0 | compact | 48 | 48 | PASS |
| 599.333 × 900 | 1.3 | compact | 48 | 48 | PASS |
| 600.000 × 900 | 2.0 | compact | 48 | 48 | PASS |
| 1440.000 × 900 | 1.0 | desktop menu | 44 | 48 | PASS |
| 1440.000 × 900 | 1.3 | compact | 48 | 48 | PASS |
| 1440.000 × 900 | 2.0 | compact | 48 | 48 | PASS |

## Regression found and corrected

Source559abdbf failed the44dp assertion: grant and confirm were40dp on Windows,
with guildTheme platform windows and VisualDensity(-2,-2). Sourcef27365fc corrected
timeout controls; the real engine then still measured compact launch40dp in8cases,
desktop44dp in1. Source3ac9ea93 corrected compact launch; b7a0582c also corrected the
existing generic admin accessibility ButtonStyle. Final exact-source rerun passed9/9.
The tests were kept strict; the initial failures are retained locally in ignored output.

## Reproduction and evidence identity

Local ignored harness is retained at `.out/native-admin-engine/host`; build command:
`flutter build windows --debug --no-pub --target lib/main.dart --dart-define=PROBE_SOURCE_SHA=b7a0582cc0a4d829d40665e0654a2eb097fd214f`.
Ignored `run.ps1` launches Hidden with a160second owned-process timeout;
each scenario has a15second bound. Scoped analyzer zero issues; debug build and process
exit0. JSON assertions above were rechecked before recording. No release distribution.

Harness source/fixture/bootstrap/lock combined SHA256: `39cf3e84c471952d99d871eeec0ff57173d69489b4a58efe303931c9174ff835`.
Committed structured result SHA256: `1116b418692831e6cb60fac57939aced37fa783e20862011ca2dd93d476b3b45`.

## Remaining acceptance

NOT_RUN: interactive physical Windows keyboard/pointer, NVDA, physical IME and OS
text-scale settings; TalkBack/VoiceOver/mobile hardware; complete #198 device matrix.
Seven-section coverage beyond the selected member/timeout path, real secure-cookie
server mutations, acoustic/media and load/release gates are outside this packet.
This record does not close those physical or production acceptance gates.
