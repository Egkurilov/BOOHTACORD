# Screen adaptation writer binding Implementation Plan

**Goal:** connect the existing calibrated slow policy to the existing serialized Web publisher, default off and without a new media owner.
**Architecture:** child `screen_adaptation/runtime_apply` owns scope snapshots, diagnostic ingress and policy result application. VoiceScreenSession supplies its real adapter and invokes ingress after its normal diagnostic read. Typed explicit pilot options supply approved classified windows; no FPS-only diagnosis or synthetic calibration enters production defaults.
**Tech Stack:** TypeScript, Vitest, existing LiveKit publisher adapter.

## Brief

Route=small_direct; driver=#169; baseline=8a6a9a3a. Preserve immutable rollout flags and source defaults, session/Room/track generations, manual quality intent, media audio and existing repair ownership. Source/test files <=120 lines, <=8 production files in new leaf. Physical calibration and enable remain NOT_RUN/NO-GO.

## Steps

- [x] Add failing real-adapter tests in `clients/web/src/voice/screen_adaptation/runtime_apply/runtime.spec.ts` and `binding.spec.ts`: `await runtime.observe(diagnostics)` must not call capture/publish with missing enable/calibration, then calibrated classified pressure invokes only `adapter.update`. Test stale diagnostics, stop/manual/new-owner races, unknown/receiver-only/static/hidden/no-subscribers, bounded downgrade/recovery and retained ceiling.
- [x] Run `npm test -- src/voice/screen_adaptation/runtime_apply` and retain missing-module red result.
- [x] Add `types.ts`, `runtime.ts`, `binding.ts` in that leaf. Runtime starts `initialScreenAdaptationState(active.profile, userCeiling, active.generation)`; evaluate existing pure policy; `change-profile` calls existing `writer.update(decision.profile)` only. Save policy state only if writer revision, active ownership/track and generation still match; failed updates keep prior effective state. External revision resets manual ceiling; own update rebases publication generation while retaining it. Binding snapshots before optional asynchronous `readWindow`, rejects changed ownership before evaluation, and exposes reason without adding frame data/logs.
- [x] Add VoiceScreenSession typed optional constructor options and `return this.adaptation.observe(await readScreenShareDiagnostics(current.room))` to its existing diagnostic path. Reset runtime during stop/cancel; no timer or additional capture/Room. Keep the file below120 lines.
- [x] Run focused adaptation/publisher/session controls tests, production `npm run build` with test-only public origin, dependency/contracts checks. Inspect exact files/status/sizes, write `evidence/screen-share/adaptation-writer-binding-2026-10-09.md`, commit exact source/tests/docs only, hand SHA to parent. No push/issues/production mutation.
