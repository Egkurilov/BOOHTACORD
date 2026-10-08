# Native admin accessibility source acceptance — #197

Date: 2026-10-09. Base: 70291c3f. Route: split_first.
Scope: actual Flutter AdminScreen rendering and its existing mutations, not a static replica.
Evidence uses synthetic typed API responses, Flutter SDK3.47.5/Dart3.13.4, Windows host.

## Source changes

- AdminScreen imports AdminAccessibleSurface through its existing build binding: SafeArea,
  logical reading traversal, transient-first platform Back/Escape and minimum44px controls.
- Actual member and tab controls expose visible2px keyboard focus and preserve their callbacks.
  Popup cancellation returns focus to its own stable per-account initiator.
- Shared confirmation helper uses closed-loop traversal, SafeArea, mounted focus return,
  Escape cancellation and zero-duration animation when disableAnimations is true.
  Role dialogs preserve their original outside-cancellation policy through an explicit argument.
- Responsive member selection accounts for text scale; search/role fields retain44px at
  scale1 and expand at larger scales without squeezing text into a fixed-height box.
- Short audit viewports, including real Scaffold IME resizing, scroll the filters and body.
  Loaded audit timestamps move into the subtitle at large scale; full actor details remain
  available in the expansion. Expanded details and desktop menus honor reduced motion.
- Member/audit loading, member/role saving, guild loading/saving, errors, concurrent conflicts
  and existing stale-readiness state expose live semantic announcements.
- Member and audit list positions use PageStorage; each expansion has its own independent
  typed storage key. This prevents the observed scroll-double/expansion-bool collision.
- Existing member filtering, pagination, role/account mutation guards, revision checks,
  topology callbacks, password-reset request/copy and protected API transport are retained.

## Physical preservation before behavioral changes

Oversized source was physically moved into native imported child leaves before modification:
member panel, member filters, tab control, audit presentation, role-permission lifecycle/actions/
rendering, guild-settings lifecycle/presentation. Public screen/panel constructors remain usable.
Nearest preservation checks passed after the mechanical conversions:
27 member/topology/media/role tests;19 tab/media/geometry tests;
12 audit/filter/scaling tests;14 role/scaling tests;14 guild/scaling tests.
All candidate Dart files are at most120 lines. Direct capability children contain at most16
production files; the accessibility test leaf contains15 files, including2 typed fixtures.

## Genuine regressions and repairs

Focused tests first failed on desktop member overflow268px at scale2, missing safe insets,
confirmation Escape failing to close, missing visible tab focus, scaled search clipping,
IME member overflow250px, audit IME overflow32px, audit error missing a live region,
audit timestamp consuming the whole tile, role dialog ignoring reduced motion150ms,
missing role conflict announcement, missing guild/member busy announcements and the
PageStorage double/bool collision during scroll/resize.
The full regression also caught normal-scale role filter46px instead of the existing44px;
normal geometry was restored while retaining scalable text layout.

## Checks and coverage

Commands run from clients/flutter unless specified otherwise:

- `flutter test --no-pub test/admin_accessibility --reporter expanded`:38 focused tests.
- `flutter test --no-pub test/admin_member_filter_test.dart test/admin_accessibility`:42 tests.
- `flutter test --no-pub --reporter expanded`: PASS:978 tests,1 existing skip,71s.
- `flutter analyze --no-pub <63 exact changed/new Dart paths>`: PASS,0 issues.
- `dart format <63 exact changed/new Dart paths>` and `git diff --check`: PASS.

Focused runtime coverage of the #197 checkboxes:

| Requirement | Evidence |
| --- | --- |
| Compact touch, no hover dependency | Actual save/reset/menu and dialog targets>=44px |
| SafeArea/IME | Mobile32/34 insets;300px keyboard; active fields and save actions visible |
| Text1/1.3/2 | All7 actual sections at390/600/1440:63 renders;14 more IME renders |
| Tab/ShiftTab/Enter/Space | Actual tabs activate; modal traversal loops both directions |
| Escape/Back/focus return | Popup;9 role confirmations; shared helper; host stays mounted |
| Resize/drafts/selection/scroll | Actual member role/filter, guild name, selected section and450px list offset |
| Loading/saving/error/stale/conflict | Actual pending futures,409 comparison and stale readiness live regions |
| Reset URL | Actual SelectableText and explicit clipboard action with a live status |
| Dark contrast/focus | Text>=4.5:1; focus>=3:1; actual local theme has2px outline |
| Pathological strings | Long login/name; loaded audit actor/target; full details retained |
| Reduced motion | Actual role modal transition0ms; expanded audit noAnimation |

## Limits and QA transfer

This is Flutter component/engine acceptance with synthetic server data. It does not assert
physical TalkBack, VoiceOver, NVDA, real Android/iOS keyboard placement or spoken announcements.
Those remain NOT_RUN and belong in device QA together with landscape/split-view, gesture Back,
OS200% text and real pointer/touch selection of the reset URL. Real production mutation and
media acceptance are outside this packet. #97 native dialog launcher is integrated by the root
agent after this source commit; its actual trigger/Escape tests must be rerun there.
An actual Windows-engine harness is a separate follow-up verification packet, not a release build.

## Desktop density regression

The engine follow-up exposed desktop compact density reducing44dp button targets to40dp. Focused actual AdminScreen save/reset tests reproduce40dp for Windows, macOS and Linux; Android standard-density baseline remains green. AdminAccessibleSurface now explicitly preserves standard density in its existing accessibility ButtonStyle, without changing the application-wide theme or input/filter geometry. All timeout/admin focused checks:83 PASS, zero skips (42 timeout and41 admin). Native physical screen-reader/IME acceptance remains NOT_RUN.
