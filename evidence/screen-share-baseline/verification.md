# Screen-share baseline harness verification

- Date: 2026-10-07
- GitHub issue: #158
- Leaf: T-032
- Base source revision: `e4cace80` (`origin/master` at worktree creation)
- Environment: Windows, Node.js 24.18.0, `livekit-client` 2.22.3

## Results

| Check | Result | Evidence |
|---|---|---|
| Baseline harness TypeScript | PASS | `npx tsc --noEmit --strict --target ES2022 --module ESNext --moduleResolution bundler --lib ES2022,DOM --types node,@playwright/test` over baseline sources/spec. |
| Baseline Playwright gate without isolated credentials | 1 PASS, 1 SKIPPED as designed | `npm run test:screen-profile` — isolated-SFU test skipped because credentials were not provided; browser encoder test passed. |
| Existing Web screen-profile suite | PASS | 6 files, 25 tests. |
| Web application typecheck | PASS | `npx vue-tsc --noEmit`. |
| LiveKit/SFU synthetic baseline | NOT_RUN | No isolated server credentials/image digest were supplied. |
| Physical display capture comparison | NOT_RUN | Requires a user-selected display and recorded device/driver details. |

The browser test does not run against production without explicit isolated test credentials. The skipped run is not a baseline measurement and does not pass an FPS or capacity gate.
