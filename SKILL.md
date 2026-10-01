# Repository working method

Use Slavik Gym v5.1 with the native projects as routing authority.

1. Classify each packet as small_direct, split_first, branch_sync or review_gate.
2. Read AGENTS.md, the native manifest and the selected capability's exact edges.
3. Record the route, preservation baseline, files, checks and stop condition.
4. Restrict source searches to that capability; follow exact imports when needed.
5. Add a focused failing behavior test before implementation changes.
6. Run the nearest native checks; release checks must reject skipped Go tests.
7. Record observed results in evidence; compilation does not prove live media.

Keep one trigger family per leaf. Aim for 100 lines per source file (hard 120)
and 8 production files/direct tests per leaf (hard 16). Existing oversized
code must be split by ownership when converting it, preserving behavior first.
Do not create route registries or generated completion receipts as substitutes
for actual source changes and tests. structure.config.yaml is a route legend.

GitHub is the sole current delivery provider under ADR-011-github-delivery.
The owner's 2026-10-01 reorganization request supersedes the obsolete GitVerse
provider assumptions in the supplied 2026-09-28 proposal. The stack, ACL,
application identities, signing identities and no-backup constraints remain.

During path migration, keep old entrypoints only as forwarding wrappers.
Never maintain duplicate runtime implementations. Remove wrappers only after
updating their callers and validating the documented canonical entrypoints.

Finish non-trivial packets with the required Slavik Gym report. Keep incomplete
physical acceptance and unavailable platform checks explicit.
