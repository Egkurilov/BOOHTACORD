# Actual upload reservation CI correction

Date: 2026-10-09. Branch: `codex/ci-upload-reservations`.
Base/API source: `8a73e84bada60a0ff537173d51ded5281957a8a7`.
Packet: small_direct, tools/qa/upload_reservations; preserve production quotas,
25MB reservation, minimum2GiB/10% reserve, capacity and writer ownership.
Stop: focused tests and actual disposable scenarios pass; root owns integration.

## Reproduced failure and cause

GitHub run37846358949/job113548106517 step9 failed the third-upload507
assertion. The fixture held two uploads for qa_admin, then uploaded again as
that same account. Production Config UploadAdmissionLimiter has AccountLimit2
and GlobalLimit16; its middleware precedes storage reservation. Thus the third
same-account request must429 before storage is reached.

Unmodified scenario executed against the actual isolated Linux API/TLS proxy,
PostgreSQL17.6 and original capacity2GiB+51,000,000: actual third response429,
followed by the original expected507 assertion failure. Owned resources removed.
This proves account admission precedence; no capacity guess or policy change.

## Correction

Keep the original two held uploads. First require429 for a third same-account
request, then use an independent participant registered and logged in through
actual API/cookie flows and require507 for that account. The peer receives its
own secure session cookie and existing channel ACL. No quota bypass, production
configuration or storage policy changes. Assertions show only bounded status
codes; passwords, cookies, bodies and real identifiers are not retained.

Focused routing tests were RED against the old scenario, then GREEN. Tests
reject peer201/403/429/503 as storage acceptance and reject weakened account
admission. Cookie test proves distinct registration/login identity and fails
closed on registration denial. CI invokes these focused tests before live run.

## Native results

WSL Ubuntu/Linux, Python3.14.4, Go1.26.4, local Unix Docker29.1.3.
Workspace-only extracted Docker CLI used because installed CLI was an unrelated
stub; no global CLI replacement or remote daemon used.

- Focused reservation tests: 8 PASS; disposable ownership/Origin/telemetry
  guards: 10 PASS. Both Windows Python3.12 and native Linux checks pass.
- Both actual `scenario(root, limited)` executions: PASS, exit0. Invocation
  directly exercised API upload scenarios; no browser/Web rebuild was needed.
  The full hosted workflow has not yet run after this commit.
- Unlimited8GiB: actual Go build overlapped six active-reservation observations;
  peak50,000,000 reserved; cancellation25,000,000; completion/retry201;
  final reservation0, staging0; two graceful stop-first API handovers.
- Limited requested2GiB+51,000,000 (observed tmpfs2,198,487,040 bytes): peak
  reservation50,000,000; actual quota429, independent capacity507, completion
  and retry201; final reservation0, staging0; two graceful handovers.
- Each actual scenario rejected a second simultaneous API writer. Headroom and
  private filesystem metrics matched the owned tmpfs within the existing1MiB
  drift bound; validator and every original cleanup assertion passed.
- Actual API binary SHA256:
  `d6ef93146077235f9dcf18118efc50989b6266a7d22167b0b0e7017d7eb79c4f`.
- Final local Docker inventory: zero labeled fixture containers, volumes or
  networks. No production/development database or attachment directory used.
- `git diff --check`: PASS. Leaf four production files/three direct test files;
  changed run.py100lines, client.py69lines, tests below120.

Ignored local evidence: `.out/upload-baseline.log`, `.out/upload-fixed.log`,
`.out/upload-fixed.json`. These contain synthetic statuses/metrics, not cookies
or credentials. No runtime outputs or installed tool archives are staged.
