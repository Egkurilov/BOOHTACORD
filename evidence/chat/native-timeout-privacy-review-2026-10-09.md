# #97 native timeout dialog privacy review

Date2026-10-09; base5315dba4, isolated codex/native-timeout-privacy-review.
Operating brief: review_gate; exact native timeout screen leaf only, preserve
authorized apply/lift behavior and transport; no root/admin/member/media edits.
Stop condition: actual DialogRoute regression, bounded remediation, native checks,
clean local commit to root. Root owns shared-confirmation Escape integration.

## Finding and fix

The actual main dialog retained the previous target's display name after losing its
captured session/deployment scope. An already-open separate apply/lift confirmation
also retained that name. The first actual route regressions reproduced the leak.

The surface renders target name only while owner.active. Dialog scopeChanges now
propagates through surface/actions to a responsibility-focused confirmation.dart.
Confirmation observes the same scope notifier and shows generic inactive content
without the target name or confirmation action. Its active callback rechecks
owner.active; commands retain their existing session/server and loaded-state guards.
No network contract, scope reopening or automatic moderation mutation changed.

## Observed checks

- PASS `flutter test --no-pub test/admin_voice_timeout`:21 cases.
- Nine new actual DialogRoute cases cross logout, same-account-ID/new session
  generation and deployment change with no confirmation, apply confirmation and
  lift confirmation. Assertions include skipOffstage:false: old name, reason,
  pending status and duration field are completely absent, Confirm is absent and
  only the original GET was sent; no PUT/DELETE.
- PASS `dart analyze lib/src/screens/admin_voice_timeout test/admin_voice_timeout`:
  no issues. Five touched Dart files are at most100 actual lines. UI leaf7 files;
  focused test leaf8 files, within target limits.
- PASS `python -m tools.ci.native.contracts`:260 tooling tests/1 existing skip,
  19 contracts,108 public/3 private endpoints,1340 Dart boundary checks and
  478 document links. Ignored `.out/native-timeout-privacy-contracts.log` retains output.

The initial red output is ignored `.out/privacy-red.log`. Server/physical media and
released device QA are not claimed; previous native full-suite evidence remains in
native-voice-timeout-2026-10-09.md, root runs the combined suite after integration.
No production mutation, PostgreSQL use, push/merge or issue mutation by this packet.

Root wiring remains showAdminVoiceTimeout(..., scopeChanges: state). Shared dialog
replacement must retain scope notification and owner.active checks in confirmation;
a captured static target-name string is insufficient after a session boundary.
