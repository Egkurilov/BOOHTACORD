# Keyboard и focus: workspace v1

Срез 25.09.2026. Это поведение исходного Vue workspace; browser-приёмка остаётся QA-05.

| Слой | Семантика | Фокус и клавиатура |
| --- | --- | --- |
| Navigation/members/search при видимом scrim | Modal dialog | `aria-modal=true`, фон `inert`, Tab/Shift+Tab внутри, Escape закрывает, фокус возвращается к вызвавшему элементу. |
| Sidebar и search на широком desktop без scrim | Обычная навигация/aside | Нет `aria-modal`, focus trap или `inert`; поиск переносит фокус в поле и возвращает его к вызвавшему элементу. |
| Встроенный поиск в личном диалоге | Обычная секция внутри беседы | Открытие переводит фокус в запрос, поиск сохраняет фокус во время ожидания ответа, Escape закрывает секцию и возвращает фокус на кнопку «Найти сообщение». |
| Профиль участника | Non-modal popover/dialog | Фокус входит на кнопку закрытия, Escape закрывает только popover, возвращая фокус на карточку участника. |
| Результат одноразовой reset-ссылки | Non-modal dialog внутри admin panel | Фокус входит в поле ссылки; Escape или кнопка закрытия удаляет ссылку с экрана и возвращает фокус на кнопку её создания. |
| Archive/voice-close confirmations | Встроенный `<dialog>` | `showModal()` удерживает фокус внутри; сначала доступна «Отмена», Escape закрывает окно и возвращает фокус на кнопку вызова. После подтверждения фокус переходит к статусу или ошибке. |
| Category/kick confirmations | Нативный `window.confirm` | Модальность и возврат фокуса обеспечивает браузер. |

PTT не перехватывает клавишу в полях, кнопках, select и dialog. Ctrl/⌘+K не перехватывается внутри текстового ввода и dialog. Видимый `:focus-visible` задан в `foundation.css`.

Локальный browser/PG прогон [архивации и закрытия входа](../../evidence/design/des03-confirmations-browser-2026-09-25-001.json) подтвердил focus на «Отмена», Escape/Cancel с возвратом на вызвавшую кнопку и status после принятия. Нужно вручную пройти QA-05 с клавиатурой и screen reader на candidate bundle: каждый размер drawer, поиск по shortcut и кнопке, вложенный профиль, reset result, все confirmations и переходы после выбора канала/DM.

[Изолированный browser-прогон DM-поиска](../../evidence/design/des05-dm-search-keyboard-2026-09-25-001.json) подтвердил фокус после открытия, Enter и Escape; полный screen-reader и release bundle прогон остаётся QA-05.
