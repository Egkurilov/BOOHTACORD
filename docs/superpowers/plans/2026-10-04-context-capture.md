# R24 context capture verification

Route: `review_gate`; leaf: Design V2 category-context capture. T-050.
Boundary: `artifacts/design-v2/dom-probe.mjs` в†’ context-menu helper.
Preserve real category handlers, permissions, reference files and product CSS.

- [x] Baseline: f9cdad74 screenshot lacks menu; fixed pointer (255,235) is outside the corrected heading starting at y=236.
- [x] Right-click a measured point inside the actual first category heading.
- [x] Assert visible menu and disabled deletion before any screenshot, even when interaction checks are disabled.
- [x] Recapture R24 and check the real create-channel action; record pointer-dependent displacement against immutable PNG.
- [x] Rebuild diffs and current review; commit only QA files and bounded evidence.

Stop: real menu visible, create form opens, no page errors; no pixel-equivalence claim for pointer-dependent placement.
