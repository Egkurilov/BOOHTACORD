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
- Readiness reason codes are internal enums. Map known codes to contextual Russian copy and never render an unknown backend value directly; keep status labels and capacity metric names aligned across Web and Flutter.

## Current verification scope

- `clients/web/src/design/uiux_copy_glossary.spec.ts` checks representative navigation, permission, and audit labels in both clients.
- Readiness reason codes map to contextual Russian copy in `clients/web/src/admin/readiness/reason_copy.ts` and `clients/flutter/lib/src/features/admin/readiness/reason_copy.dart`; unknown values never reach the UI. Probe status and storage metric labels match across the clients.
- The 320 px readiness browser case confirms that the two-line status slot prevents data cards from moving during refresh and after a 503. Web/Flutter tests cover long device labels: the Web native select retains the full option and `title`, while Flutter keeps an ellipsized control with full tooltip and semantics text. Device IDs stay hidden.
- The six #304 source screenshots were compared with source-sized after captures and are listed with hashes in `evidence/qa/qa304-copy-visual-review-2026-10-10.json`. Audit timestamps remain grouped by local date with visible `HH:MM`; the full localized timestamp is inside the event-details disclosure. Role-permission warning content is scrollable above the persistent mobile save actions.
- The browser accessibility gate includes a reduced-motion smoke for transition duration and scroll behavior.
- The review records intentional changes such as collapsed advanced stream-quality settings. They remain available on demand; desktop top/action screenshots are separate because the dialog content scrolls in a 900 px viewport.
