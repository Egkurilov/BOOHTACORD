# Сквозная регрессия IMP-42 — 12 сценариев

Каждый сценарий выполняется на фиксированном disposable candidate с SHA, независимыми cookie jars и синтетическим содержимым. Кодовые, PostgreSQL, browser, hardware, load и deployment доказательства фиксируются раздельно; ни один пункт сам по себе не закрывает весь QA-гейт. Действующие runbooks и [QA-критерии](../VERIFICATION_TODO.md) имеют приоритет. Сценарии из вложенного функционального аудита ещё не выполнены этим документом.

| № | Сценарий и проверяемый итог | Основной gate |
|---:|---|---|
| 1 | A↔B создают/ищут/редактируют/удаляют DM и файл; C-администратор вне пары не видит историю, hints, preview/download, счётчики и notification content. | QA-03/05 |
| 2 | Потерян ответ send после commit; повтор с тем же `client_message_id` даёт одну запись и те же attachment links. | QA-03/05 |
| 3 | Upload/send A, переход в B, изменение draft, поздний ответ A, возврат в A: ни файл, ни текст, ни cursor не мигрируют между контекстами. | QA-05/13, IMP-07 |
| 4 | Устаревший edit revision и удаление во время редактирования не возвращают body и не затирают новую версию. | QA-05/13 |
| 5 | Длинная история, unread boundary, reply/search hit и возврат сохраняют anchor; read cursor движется только по видимым записям и только вперёд. | QA-05/13, IMP-08/09 |
| 6 | Две вкладки, permission deny, delayed lock и смена аккаунта: ни дубля, ни уведомления прежнего пользователя. | QA-03/05 |
| 7 | Разрыв только application WS не рвёт живой WebRTC; REST resync не создаёт lease; authoritative revoke завершает оба контура. | QA-06/10 |
| 8 | Все причины POC-03 с observer: старые API-issued и SDK-refreshed credentials отклонены, соседний lease не затронут. | QA-10 |
| 9 | Переключение screen A→B→A, поздняя audio track, rename и source ended: один выбранный поток, старый звук отключён; mini/full только после IMP-28 ADR. | QA-06/07, IMP-28 |
| 10 | Mute→deafen→restore, PTT blur, unplug/replug, default change и sleep/wake: нет неожиданной передачи, реальный peer подтверждает звук. | QA-06/13 |
| 11 | Concurrent upload, abort, 507→retry, statfs/DB/FS fault и bounded cleanup: reservations освобождаются, опубликованные файлы и живые ссылки сохранены. | QA-08/05 |
| 12 | Совместимый digest-only rollback с двумя observers/volume checks и signed Android update с OS capture stop/background/foreground. | QA-12/13 |

Для 1–6 достаточно доверенного браузерного стенда и PostgreSQL; 7–10 требуют настоящего LiveKit и физических/разрешённых media-клиентов; 11 — изолированного capacity-limited volume; 12 — согласованного окна rollback и физического Android. Нагрузочные или destructive пробы не выполнять на production по одному факту наличия списка.
