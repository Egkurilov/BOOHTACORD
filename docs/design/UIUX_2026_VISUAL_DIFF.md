# UIUX-2026 screenshot region review

`python3 -m tools.verify.uiux_visual_diff` reports RGB deltas for named screenshot regions. It is a review aid, not a screenshot acceptance gate: the audit archive contains design references, not owner-approved pixel goldens, and this tool never decides whether a visual change passes.

## Compare a pair

Use before/after PNGs with identical raster dimensions. Save a JSON config beside the captures or use absolute paths:

```json
{
  "reference": "before.png",
  "actual": "after.png",
  "channelThreshold": 20,
  "regions": [
    { "name": "conversation-toolbar", "rect": [560, 0, 2320, 130] },
    { "name": "composer", "rect": [600, 1600, 1750, 200] }
  ],
  "ignoreRegions": [
    { "name": "account-avatar", "rect": [24, 24, 64, 64] }
  ]
}
```

Rectangles use raster pixels in `[x, y, width, height]` form. Regions identify stable controls or layout areas. Ignore rectangles remove dynamic pixels such as avatars, timestamps, or backend-provided values from the selected region. Prefer excluding a dynamic region over masking broad areas that contain controls.

Run the report with an output path outside tracked source captures:

```sh
python3 -m unittest tools.verify.test_uiux_visual_diff
python3 -m tools.verify.uiux_visual_diff \
  --config .out/uiux-visual-review/pair.json \
  --report .out/uiux-visual-review/report.json
```

The report records input paths and SHA-256 values, raster dimensions, compared/ignored pixel counts, mean absolute RGB change, and the number/percentage of pixels whose largest channel delta exceeds `channelThreshold`. Metrics are descriptive and have no implicit pass/fail cutoff.

## Review and baseline changes

1. Capture both states from the same app revision, account fixture, viewport, device-pixel ratio, theme, and interaction state. Record any unavoidable environment differences.
2. Name each stable UI region and document every ignored dynamic rectangle. Keep the reference and actual image hashes with the report.
3. Inspect the source, after image, and the measured regions together. Classify each difference as expected, an approved design change, or a regression; a large percentage alone is not a regression verdict.
4. Promote a reference image to an approved golden only after the UI owner accepts the state and raster. Record that approval and the baseline revision separately. Until then, retain the report for review and do not add a numeric CI threshold.
5. Keep captures under ignored `.out/` or a retained workflow artifact. Do not stage generated screenshots or replace the pinned audit archive as part of routine baseline refreshes.

The frontend workflow runs the small PNG-reader unit suite. Its browser tests retain responsive-shell captures for 30 days. A `[skip ci]` checkpoint has no GitHub Actions artifact; local report paths are not represented as published artifacts.
