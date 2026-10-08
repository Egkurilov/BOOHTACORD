# Native admin accessibility (#197)

Classification split_first; base70291c3f. Root converted admin_screen to native
child leaves. Own shell accessibility, member layout/filter presentation,
confirmation focus handling and status semantics; preserve all49methods/ACL,
draft/controller ownership and secure account APIs. Voice timeout leaves belong
to finish_archive and are excluded from this packet.

1. Baseline actual seven admin sections at390/600/1440, text1/1.3/2 using
   MediaQuery inside MaterialApp; compact touch geometry, IME/safeinsets, keyboard
   and popover/dialog return, resize drafts and pathological names/reset URLs.
2. Physically split oversized touched members/filter/tab presentation into owned
   child leaves before behavior edits. No source/test >120lines/leaf16files.
3. Add failing tests for observed source gaps before safearea/touch/IME, logical
   traversal/live status/reducedmotion fixes. Keep focus/selection state native;
   do not mask overflow by shrinking text or removing controls.
4. Repeat full scope matrix + focused admin/widget tests, native analyze and full
   regression. Record source/emulation PASS separately from physical TalkBack,
   VoiceOver and IME NOT_RUN. Root owns integration/Windows runtime coordination.

Stop: reachable issue197 checklist source covered with concrete tests; honest
QA acceptance instructions remain for unperformed device/runtime checks.
