# Native channels and people quick jump — #78

Based on the approved one-guild behavior and the root Web/native-title dependency (da590507). BOOHTACORD branding remains. Existing configured guild labels and dynamic notification titles remain the root packet's responsibility.

## Implemented behavior

The real workspace search header now switches between message search and **Каналы и люди**. Message search state, Ctrl/Cmd+K guards, focus restoration and existing geometry remain. The native panel uses authorized topology, existing participant DMs, and explicitly paged server-authorized DM candidates. It excludes self and duplicate DM peers, supports case-insensitive names, displays loading/failure/retry, and provides explicit subsequent-page loading.

Selection refreshes authorized topology or DMs before opening. A newly selected person uses the existing authenticated DM POST, then refreshes the authoritative DM list and verifies both participant and conversation. A denied/revoked target never navigates. Voice targets invoke only existing channel navigation, which loads channel state without VoiceJoin. Media lifecycle is unchanged.

The owner captures the account/session boundary, rejects late responses after logout/disposal, clears candidates on disposal, and does not log people, conversations or message bodies. Keyboard arrows/Enter select entries; composing IME Enter is ignored. Labels use a single line with ellipsis.

## Native ownership

- Typed paging DTO and facade: features/direct/conversations (existing endpoint, no server contract change).
- Candidate load, entries and selection: features/workspace/quick_jump/state, six source files.
- Application binding and real widgets: screens/guild_quick_jump, four source files.
- Exact native integration: workspace_search_panel header, context, render and child navigation_panel.

All owned production and direct test files are <=120 lines. No dependency-validator exception, static reference implementation, microphone preflight or implicit media connection was added.

## Observed checks

Flutter 3.47.5 / Dart 3.13.4:

- Initial focused API/controller red runs failed on missing new page/controller APIs.
- Focused API, owner, authorization, session and actual-widget tests: PASS 13.
- Workspace/prejoin/quick-jump preservation run before the final two additive session/cursor checks: PASS 96, including all 79 original workspace cases and 6 roster UI/header checks. Final two checks independently PASS.
- Scoped Flutter analyzer: PASS, no issues.
- python -m tools.verify.dependencies.dart: PASS (1178 Dart files).
- Native formatter and candidate file sizes: PASS.

The actual component test uses a 390×844 logical viewport and exercises Enter to open a server-authorized DM; a separate widget test rejects composing IME Enter. These are component acceptance, not physical device acceptance.

## QA remaining

Windows/Android/iOS keyboard and screen-reader checks, long localized names and large paged guilds, and live server revocation/account switching: NOT_RUN on physical devices. Verify page boundaries and retry over a real network, existing voice remains connected while opening people/channels, and switching back restores message search. The parent integrates the dependency and runs the full client/release checks.

Slavik Gym report: route=screens/guild_quick_jump + features/workspace/quick_jump/state; packet=small_direct; tokens=estimated:12000; method=manual_estimate; driver=issue78 native authorized people parity; next_split=Windows overlay settings.
