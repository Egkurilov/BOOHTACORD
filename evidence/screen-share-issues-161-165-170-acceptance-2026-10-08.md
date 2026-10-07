# Screen-share issues #161 and #165–#170 — acceptance follow-up

Date: 2026-10-08. Source baseline: `origin/master` at `9b524569`.
This packet reviewed existing merged implementation; it did not change application code or close issues.

## Issue comments posted

Each comment distinguishes existing automated checks from device, SDK/SFU, browser, or production checks that remain `NOT_RUN`. Comments define the platform/scenario matrix and redacted evidence fields expected for a future PASS/FAIL result.

| Issue | Existing implementation / evidence | Acceptance comment |
|---|---|---|
| #161 | [PR #186](https://github.com/Egkurilov/BOOHTACORD/pull/186), [PR #201](https://github.com/Egkurilov/BOOHTACORD/pull/201), [publisher lifecycle verification](https://github.com/Egkurilov/BOOHTACORD/blob/master/evidence/screen-share-publisher-lifecycle/verification.md) | [comment](https://github.com/Egkurilov/BOOHTACORD/issues/161#issuecomment-6047860672) |
| #165 | [PR #204](https://github.com/Egkurilov/BOOHTACORD/pull/204) | [comment](https://github.com/Egkurilov/BOOHTACORD/issues/165#issuecomment-6047861068) |
| #166 | [PR #202](https://github.com/Egkurilov/BOOHTACORD/pull/202), [QA-319 capture-plan evidence](https://github.com/Egkurilov/BOOHTACORD/blob/master/evidence/flutter/qa319-flutter-desktop-screen-share-capture-plan-2026-10-07-001.json) | [comment](https://github.com/Egkurilov/BOOHTACORD/issues/166#issuecomment-6047861395) |
| #167 | [PR #208](https://github.com/Egkurilov/BOOHTACORD/pull/208) | [comment](https://github.com/Egkurilov/BOOHTACORD/issues/167#issuecomment-6047861689) |
| #168 | [PR #206](https://github.com/Egkurilov/BOOHTACORD/pull/206) | [comment](https://github.com/Egkurilov/BOOHTACORD/issues/168#issuecomment-6047862010) |
| #169 | [PR #207](https://github.com/Egkurilov/BOOHTACORD/pull/207), [adaptation policy verification](https://github.com/Egkurilov/BOOHTACORD/blob/master/evidence/screen-share-adaptation/verification.md) | [comment](https://github.com/Egkurilov/BOOHTACORD/issues/169#issuecomment-6047862346) |
| #170 | [PR #211](https://github.com/Egkurilov/BOOHTACORD/pull/211), [metadata evidence](https://github.com/Egkurilov/BOOHTACORD/blob/master/evidence/issue-170-screen-profile-metadata-2026-10-07.md) | [comment](https://github.com/Egkurilov/BOOHTACORD/issues/170#issuecomment-6047862697) |

## Verification status

- Existing PR records report the relevant focused/unit/CI checks as passing: #161 lifecycle and Web checks; #165 CI run 648; #166 source review only; #167 Android helper JUnit 12/12; #168 18 focused tests and `vue-tsc`; #169 10 tests and `vue-tsc`; #170 PR CI run #680 including backend, frontend, and lifecycle jobs.
- Physical Android, Windows, macOS, iOS, cross-client viewer, hardware codec A/B, calibrated adaptation, deployed descriptor API, and production teardown values remain `NOT_RUN` as applicable. No measured media numbers were inferred from target profiles or source settings.
- This worktree has Node/npm but no Flutter or Dart executable and no `clients/web/node_modules`; no local test was run in this packet. The linked issue comments specify commands and evidence needed to collect those results on suitable runners/devices.
- No credentials, SDP, private identifiers, user media, or screen images were added to this evidence record.
