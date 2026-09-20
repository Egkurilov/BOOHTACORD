# Bootstrap packet

Work on the next dependency-ready leaf from `backlog/tasks.yaml`; avoid parallel edits to a shared leaf. Start with a failing targeted test, then make the smallest implementation that fulfills the contract. The source product brief is `C:\Users\egkur\Downloads\TZ_Voice_Platform_v1.0.md`.

The release sequence is mandatory:

1. POC-01 proves real game capture and audio with simultaneous voice on physical Windows and macOS machines.
2. POC-02 fixes supported browser/OS and video-profile claims from measurements.
3. POC-03 proves media admission and token replay resistance.
4. Feature work and end-to-end validation proceed only against the versioned contracts.
5. Capacity, security and deployment gates need evidence, not a green linter or a mocked demo.

Stop and record `BLOCKED` when an unknown depends on real hardware, owner-owned production inputs, network provisioning or a decision that changes product scope. Do not invent an answer.
