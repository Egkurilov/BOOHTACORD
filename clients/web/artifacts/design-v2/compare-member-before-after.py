"""Compare the same mobile member fixture before and after the sheet change.

These are before/after diffs, not PNG-golden acceptance metrics.
"""

import json
import os
from pathlib import Path

import numpy as np
from PIL import Image, ImageChops


root = Path(os.environ["DESIGN_V2_ARTIFACT_DIR"])
metrics = {}
for name in ["member-long-offline-390", "member-long-offline-320", "member-avatar-390"]:
    before = Image.open(root / "baseline" / f"{name}-before.png").convert("RGB")
    after = Image.open(root / f"{name}-actual.png").convert("RGB")
    if before.size != after.size:
        raise ValueError(f"{name}: before/after viewports differ")
    delta = np.abs(np.asarray(before, dtype=np.int16) - np.asarray(after, dtype=np.int16))
    metrics[name] = {
        "viewport": before.size,
        "mean_absolute_rgb_change": round(float(delta.mean()), 3),
        "pixels_changed_over_20_percent": round(float((delta.max(axis=2) > 20).mean() * 100), 3),
    }
    ImageChops.difference(before, after).save(root / f"{name}-before-after-diff.png")
    Image.blend(before, after, 0.5).save(root / f"{name}-before-after-overlay.png")
(root / "member-before-after-metrics.json").write_text(json.dumps(metrics, ensure_ascii=False, indent=2), encoding="utf-8")
print(json.dumps(metrics, ensure_ascii=False, indent=2))
