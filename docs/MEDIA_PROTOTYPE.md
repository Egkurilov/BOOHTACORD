# Media prototype protocol

## POC-01 — real game audio and capture

Run separately on a Windows machine and an Apple-Silicon macOS machine with a second physical observer machine. Record hardware, OS build, Chrome stable version, input/output devices, LiveKit image digest, game and capture source. The presenter joins voice, starts the real game, chooses a browser-offered source, shares it with audio, and speaks. The observer selects that stream while hearing room voice.

The reproducible operator procedure, controlled topology preflight and evidence classification are in [POC_01_OPERATOR_RUNBOOK.md](POC_01_OPERATOR_RUNBOOK.md). It adds execution detail only; this protocol remains the source of the POC-01 acceptance rule.

Pass only when the observer sees moving game content, hears game audio and presenter speech, and the presenter does not receive the observer's own playout as a sustained digital loop. Record timestamps and artifacts. A track being present or tab-only audio is insufficient. If game audio cannot be supplied on an OS, record `BLOCKED` with the observed browser/source limitation; do not silently substitute desktop software, a driver or virtual cable.

## POC-02 — profile measurements

For 720p/30, 720p/60, 1080p/30 and 1080p/60 use moving game content and record selected target, measured dimensions, decoded FPS, bitrate, RTT, loss and adaptation/recovery behaviour. Repeat under impaired observer network. The claim of a supported profile comes only from a `PASS` record; the UI must always separate target from measured values.

## POC-03 — revocation

With a connected publisher and observer, exercise kick, ban, logout, session revocation and voice-channel deletion. Attempt reconnection and replay of a previously issued API media token and LiveKit SDK token after each action. Pass only when the revoked actor cannot publish, subscribe or re-enter and the unaffected caller receives a truthful outcome. Capture the pinned LiveKit version/digest.

## Evidence

Store one JSON record under `evidence/` per run using `templates/evidence.json`. `PASS` requires artifact paths and an observer. `FAIL` identifies the failed expected result. `BLOCKED` identifies an external prerequisite. `NOT_RUN` never satisfies a release gate.
