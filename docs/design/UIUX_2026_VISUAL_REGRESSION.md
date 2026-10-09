# UI/UX 2026 visual regression inventory

This inventory supports epic [#289](https://github.com/Egkurilov/BOOHTACORD/issues/289) and verification task [#302](https://github.com/Egkurilov/BOOHTACORD/issues/302). The machine-readable 41-slot screen catalog is [`clients/web/tests/uiux_2026/visual_matrix.json`](../../clients/web/tests/uiux_2026/visual_matrix.json); its Vitest contract ensures the desktop/mobile counts, fixture/test paths, viewport targets, expected behavior and owner field stay populated.

## Reference archive status

The original archive is checked in at [`artifacts/ui-ux-screenshots.zip`](../../artifacts/ui-ux-screenshots.zip). Its embedded README lists all 41 PNGs (18 desktop, 23 mobile); `D18` and `M23` are `desktop-channel-log.png` and `mobile-channel-log.png`. The catalog records the archive SHA-256, each filename, the CSS viewport, and the PNG raster size. Desktop references are 1440×900 CSS px / 2880×1800 raster px. Mobile references are 393×852 CSS px / 1179×2556 raster px, except the two stream-launch references at 786×1704.

The source archive does not include the current branch's “after” screenshots. The 1440×900 and 393×852 targets below match the source capture dimensions; the separate #302 regression sweep also includes 390×844 from #290.

Current browser captures are runtime review artifacts, not before/after comparisons against the audit. A synthetic fixture must not be presented as an application screenshot or an approved visual golden.

## Automated viewport coverage

`npm run test:responsive-shell` runs the production responsive-shell CSS and workspace drawer-history/focus helpers at 12 sizes. It checks shell/composer/voice-dock bounds, document overflow, selected-channel retention, drawer behavior, browser Back/Forward, voice context, focus containment and focus restoration. The six required #302 sizes and both exact source-reference CSS sizes are captured on each run:

| Viewport | Capture |
| --- | --- |
| 320×640 | `shell-320x640.png` |
| 390×844 | `shell-390x844.png` |
| 768×1024 | `shell-768x1024.png` |
| 1024×768 | `shell-1024x768.png` |
| 1440×900 | `shell-1440x900.png` |
| 1920×1080 | `shell-1920x1080.png` |
| 393×852 | `shell-393x852.png` |

The images are emitted under `.out/responsive-shell-browser-results/` and retained as the `ux-responsive-shell-<commit>` artifact by `ci-frontend.yaml`. They are review captures; the current test checks geometry and state invariants, not pixel equality to a golden. CI wiring is in `tools/ci/native/web.py`.

`python3 -m tools.verify.uiux_visual_matrix` validates the pinned archive SHA-256, all 41 archive entries, PNG dimensions and catalog mappings. The catalog contract test validates the counts and references. The current shell sweep complements focused production-component browser fixtures for message actions, DM/search, admin states, settings, dialogs and voice/stream setup. Flutter has focused widget/layout coverage listed per catalog entry. These suites do not collectively prove that every one of the 41 source screens has a matching, source-backed golden.

## Remaining work for #302

- Bind each catalog slot to a dedicated, runnable Web and Flutter fixture; the existing fixtures cover representative behaviors, not all 41 full screens.
- Add approved, deterministic after captures and before/after comparisons for all critical flows, with documented dynamic-region masks and exceptions.
- Run the Flutter golden matrix on compact/medium/expanded layouts, text scale 1×/2×, dark theme, safe-area and IME fixtures; retain its review artifacts.
- Run the connected GitHub Actions workflow and verify the browser captures are attached. The latest user-requested `[skip ci]` push does not provide a workflow artifact.

Source-image presence and catalog validation are not visual PASS; after captures and comparisons remain outstanding.
