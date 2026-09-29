# Windows x64 client

The local `BOOHTACORD-1.0.3+7-windows-x64.zip` bundle was built from
`53b4e2d02bd7600da5ba6ae58e71a744bb4062c4` with Flutter 3.47.5 and
Visual Studio Build Tools 2022. The archive is local and is ignored by Git.

Extract the entire archive to a writable directory, then run
`boohtacord_desktop.exe` from that directory. Keep the adjacent DLL files and
`data/` directory together with the executable. The client requires the
guild's HTTPS API and LiveKit service.

SHA-256 of the local ZIP:
`AA63147AB08E9C3ADE7C28BE64F69A2BEA295129F6E93A1D3505016BE83B7722`

Build and verification details are recorded in
[`QA-108`](../../evidence/flutter/qa108-windows-desktop-bundle-2026-09-29-001.json).
The compiled app opened a responsive BOOHTACORD window on this Windows host.
Login, voice, screen sharing, and second-peer behavior still need runtime
acceptance before calling this a public release.
