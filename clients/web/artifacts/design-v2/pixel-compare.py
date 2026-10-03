"""Compare captured Vue screens with the immutable Design V2 PNG references."""
import json
import os
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageChops


root = Path(os.environ["DESIGN_V2_ARTIFACT_DIR"])
metrics = {}
for screen in sys.argv[1:]:
    reference = Image.open(root / f"{screen}-reference.png").convert("RGB")
    actual = Image.open(root / f"{screen}-actual.png").convert("RGB")
    if actual.size != reference.size:
        raise ValueError(f"{screen}: viewport differs: {actual.size} vs {reference.size}")
    delta = np.abs(np.asarray(actual, dtype=np.int16) - np.asarray(reference, dtype=np.int16))
    metrics[screen] = {
        "mean_absolute_error": round(float(delta.mean()), 3),
        "pixels_over_20_percent": round(float((delta.max(axis=2) > 20).mean() * 100), 3),
        "viewport": actual.size,
    }
    ImageChops.difference(reference, actual).save(root / f"{screen}-diff.png")
    Image.blend(reference, actual, 0.5).save(root / f"{screen}-overlay.png")
(root / f"{sys.argv[1]}-{sys.argv[-1]}-pixel-metrics.json").write_text(json.dumps(metrics, ensure_ascii=False, indent=2), encoding="utf-8")
print(json.dumps(metrics, ensure_ascii=False, indent=2))
