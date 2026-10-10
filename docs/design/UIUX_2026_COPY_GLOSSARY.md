# UI/UX 2026 copy glossary

This glossary covers user-facing copy reviewed for issue #304. It keeps the Web and Flutter clients aligned without renaming API fields, permission keys, event codes, or backend entities.

| Meaning | Preferred UI copy | Usage |
| --- | --- | --- |
| Guild | гильдия | Use for the one deployed server/workspace users belong to. Keep channel and guild settings visibly separate. |
| Compact admin shell title | Админ | Use only as the narrow-shell visual title. Keep the full accessible title “Администрирование” and the admin panel heading. |
| Group of channels | раздел | Use in navigation, role permissions, ordering, mutation feedback, and audit summaries. The API value remains `CATEGORY`. |
| Text or voice destination | канал, текстовый канал, голосовой канал | Use “раздел” for its parent and “канал” for the destination itself. |
| Join a voice channel | Подключиться | Use for the primary join action; describe active state as “Вы подключены”. |
| Screen sharing | демонстрация экрана | Use for the feature and its controls. “Трансляция” may describe the media quality/transport while an active demonstration is running. |
| Chat content | сообщения | Use in navigation, search, retention, and empty states; never expose message bodies in admin diagnostics. |
| Refresh | Обновить | Add the object when it helps disambiguate, for example “Обновить проверку” or “Обновить список”. |

## State and helper copy

- Put one useful instruction before advanced settings. Keep required platform, privacy, security, and media limitations available beside the affected control.
- Distinguish initial loading, refresh with retained data, empty, stale, error, and success states. Name the affected object and provide a retry or next action when one exists.
- Keep saved/dirty/pending feedback next to its form. Do not replace a contextual failure with a generic “Ошибка”.
- Put technical measurements and implementation detail behind a clearly named advanced disclosure. Long values must wrap or have a deliberate way to inspect the complete value.
- Icon-only controls need an accessible action name. Selected, disabled, busy, and destructive states use their semantic Design V2 treatments.
- Honor `prefers-reduced-motion`; opening, loading, and error feedback must not move surrounding content unexpectedly.

## Current verification scope

- `clients/web/src/design/uiux_copy_glossary.spec.ts` checks representative navigation, permission, and audit labels in both clients.
- The browser accessibility gate includes a reduced-motion smoke for transition duration and scroll behavior.
- Reference screenshots named in #304 were not present in the checkout. This document and source review do not substitute for before/after visual comparison or the outstanding viewport/content review.
