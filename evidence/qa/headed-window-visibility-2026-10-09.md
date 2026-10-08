# Headed window visibility acceptance correction

Development smoke PASS; full hosted acceptance pending.
Exact old CI job113548107235 failed because bringToFront left the original page
visible; the actual application read cursor assertion was not reached.
Locked Playwright1.63 enables focus emulation on newly owned pages, forcing their
visibility. Turning off emulation from a second CDP session did not remove the
original session override. Window bounds could say minimized while DOM stayed
visible. This reproduced on real Windows Chromium153.

Correction: start only a disposable owned Chromium/profile, attach to its default
context with documented noDefaults=true, then minimize/restore its actual native
window. A loopback CDP endpoint is discovered without exposing credentials. The
profile is removed after child exit; no existing browser/profile is used.
The self-signed disposable TLS exemption matches the previous harness, not any
product/runtime option. The Linux runner has a real supervised Openbox manager.

2026-10-09 observations:
- Normal Playwright window minimized but document visible: FAIL reproduced.
- Owned native browser hidden -> visible witness: PASS Windows and Linux
  Ubuntu/Xvfb/Openbox using locked Chromium153. No document property replacement,
  synthetic visibility event, application guard weakening or skipped assertion.
- Owned profile count after smoke: zero. Node syntax/diff checks PASS.
- Full actual TLS/PostgreSQL/LiveKit unread/upload journeys await hosted exact-head
  workflow; this smoke does not prove their database/media acceptance.

Primary API: https://playwright.dev/docs/api/class-browsertype#browser-type-connect-over-cdp
noDefaults leaves focus emulation disabled only for the default context. Secondary
contexts used for isolated ACL actors are preserved, not used as background proof.
