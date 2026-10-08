# Headed visibility acceptance plan

Route review_gate: tools/qa/next_client_acceptance background unread witness.
Existing CI reproduces document.visibilityState visible after bringToFront in
Xvfb without a window manager. Do not override document visibility in JavaScript,
skip the assertion, or alter the application's read cursor guard.

1. Add actual headed Chromium witness for native window minimize/restore.
2. Minimize the owned browser window through its native CDP window API and await
   the genuine DOM visibility transition before background read assertions.
3. Restore the window in finally before foreground cursor observation.
4. Supply a real window manager on the disposable Linux runner and supervise its
   lifetime; retain failures. Run both full capacity/native PostgreSQL scenarios.

Limits target100/hard120. Stop: actual hidden/visible browser witness and full
scenario PASS; no synthetic visibility replacement or product behavior changes.
