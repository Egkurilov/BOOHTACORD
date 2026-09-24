# Search shortcut focus guard

**Goal:** Make the existing Ctrl/⌘K message-search shortcut respect keyboard focus and IME input, as a focused DS-T10 accessibility/resilience fix.

**Scope:** Only the search shortcut. This does not close the full keyboard, reconnect, authenticated-browser, screenshot, or physical POC gates.

## Files

- `frontend/src/search/search_shortcut.ts` — pure shortcut eligibility rule.
- `frontend/src/search/search_shortcut.spec.ts` — regression tests for editable targets, modifiers, repeats, and composition.
- `frontend/src/search/SearchLauncher.vue` — apply the rule before consuming the key event.
- `docs/design/GUILDCHAT_V1_TODO.md` — record the completed slice and remaining manual review.

## Steps

1. Add failing tests for normal Ctrl/⌘K, editable controls/contenteditable, wrong modifiers, repeated keydown, and IME composition.
2. Implement the pure eligibility predicate and wire the launcher to it.
3. Run focused and full frontend tests, build, and `git diff --check`.
4. Keep DS-T10 PARTIAL until the remaining keyboard/focus/reconnect review is evidenced.
