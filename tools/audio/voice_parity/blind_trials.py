"""Prepare private operator assignments and an anonymous listener score sheet."""
import argparse
import csv
import itertools
import json
import random
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
DIRECTIONS = ["web-windows", "windows-web", "web-web", "windows-windows"]
SCENARIOS = ["clean", "keyboard", "fan", "double-talk"]
LOSS = [0, 1, 3]

def trials(mobile=False, isolation=False, rng=None):
    rng = rng or random.SystemRandom()
    profiles = json.loads((ROOT / "contracts/voice-audio-profile.json").read_text(encoding="utf-8"))["profiles"]
    directions = DIRECTIONS + (["web-android", "android-web", "web-ios", "ios-web"] if mobile else [])
    processing = list(itertools.product([False, True], repeat=3)) if isolation else [(True, True, True)]
    if isolation:
        profiles = [profile for profile in profiles if profile["id"] == "baseline-128-v1"]
    variants = [
        {"direction": direction, "profile": profile["id"], "loss_percent": loss,
         "scenario": scenario, "agc": agc, "aec": aec, "ns": ns}
        for direction, profile, loss, scenario, (agc, aec, ns)
        in itertools.product(directions, profiles, LOSS, SCENARIOS, processing)
    ]
    rng.shuffle(variants)
    return [{"trial": f"T{index:04d}", **variant} for index, variant in enumerate(variants, 1)]

def write_plan(destination, assignments):
    destination = destination.resolve()
    if any((parent / ".git").exists() for parent in [destination, *destination.parents]):
        raise ValueError("Keep operator assignments and listener results outside Git checkouts.")
    destination.mkdir(parents=True, exist_ok=False)
    (destination / "operator-private.json").write_text(json.dumps(assignments, indent=2), encoding="utf-8")
    columns = ["trial", "intelligibility_1_5", "pumping_0_3", "metallic_0_3",
               "clipping_0_3", "quiet_0_3", "guessed_sender_platform", "confidence_1_5", "usable"]
    with (destination / "listener.csv").open("w", newline="", encoding="utf-8") as output:
        writer = csv.DictWriter(output, fieldnames=columns)
        writer.writeheader()
        writer.writerows({"trial": assignment["trial"]} for assignment in assignments)

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("output", type=Path)
    parser.add_argument("--mobile", action="store_true")
    parser.add_argument("--dsp-isolation", action="store_true")
    args = parser.parse_args()
    assignments = trials(args.mobile, args.dsp_isolation)
    write_plan(args.output, assignments)
    print(f"{len(assignments)} blinded trials prepared; no acoustic PASS is inferred.")
