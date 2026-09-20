# Acceptance and release gates

## Functional gates

- An unauthenticated visitor cannot read history, membership, attachments or receive media credentials.
- A Member can register, join public channels, voice and a single 1:1 DM; an Administrator can manage only the documented guild resources and never read a third party DM by role.
- A voice user can explicitly choose devices, listen after microphone denial, mute/deafen, reconnect after a transient network break and transfer a single voice lease.
- Screen sharing uses the browser picker, separate tracks and one selected remote stream; stopping or switching a stream does not create duplicate audio.
- Attachments are capped at 25,000,000 bytes and authorize every download. Published chat/attachments have no automatic retention expiry.

## Measured gates

On the selected normal network, record p95 voice join after permissions ≤3 s, message/WebSocket delivery ≤500 ms, selected-stream switch ≤2 s and voice reconnection ≤10 s. The mandatory ACL test suite has zero confirmed violations. POC-01 proves Windows and macOS game audio/capture/voice without loop. POC-02 supports claims about Chrome/OS/video profiles. POC-03 proves media revocation/replay behaviour.

The load gate separately measures 100 simultaneous guild voice participants, up to 20 in a voice channel, and up to one screen source per participant without an artificial product stream quota. A transport-only load generator does not prove capture quality or macOS behaviour.

## Release decision

Release requires all required automated checks, current Windows/macOS hardware evidence, capacity evidence on selected infrastructure, CI/CD deploy/smoke evidence and no unresolved security or agreed user-scenario blocker. The production deploy additionally needs owner-supplied repository, registry, domain, DNS/TLS, SSH and network inputs. Green UI mocks or lint do not close any media/capacity/security gate.
