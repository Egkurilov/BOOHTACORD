# TODO — BOOHTACORD: оставшаяся работа

Срез 27.09.2026 по `master`, утверждённому ТЗ, [реестру задач](backlog/tasks.yaml), исходникам и evidence. Здесь **22 открытых верхнеуровневых пакета: BE 0, FE 4, DES 8, QA 10**. Ещё **26 нативных подзадач** вложены в QA-13 и перечислены в [Flutter parity checklist](docs/flutter-web-parity-todo.md); они не прибавляются повторно к числу пакетов. Подтверждённая реализация и закрытые QA вынесены в [DONE.md](DONE.md), [DONE_RECENT.md](DONE_RECENT.md) и [DONE_AUDIT_2026-09-27.md](DONE_AUDIT_2026-09-27.md). Частично проверенный пакет остаётся открытым до своего полного критерия.

Дополнительные задачи из функционального аудита ведутся отдельно в [аналитическом TODO](backlog/IMPROVEMENTS_TODO.md). На 28.09: документационный `IMP-41` выполнен; web/Go source для черновиков, проверки звука, персональной границы unread, метрик roster и opt-in мини-плеера частично готов. Их browser/PostgreSQL/device приёмка и полный критерий по-прежнему открыты. Android-код этим пакетом не меняется.

## Бэкенд — [критерии и тесты](backlog/BACKEND_TODO.md)

Открытых задач нет. BE-19/20 и результаты их PostgreSQL-проверок — в [DONE_RECENT.md](DONE_RECENT.md).

## Фронтенд — [критерии и тесты](backlog/FRONTEND_TODO.md)

- [ ] **FE-52 · P1:** собрать Android sender FPS/bitrate/RTT во время трансляции и сопоставить с двумя зрителями после обновления APK.
- [ ] **FE-53 · P1:** открывать изображение в TEXT/DM в защищённом viewer внутри чата; скачивание — отдельным действием.
- [ ] **FE-54 · P1:** вставлять изображение из clipboard в TEXT-редактор и отправлять с текстом либо без подписи.
- [ ] **FE-55 · P1:** вставлять изображение из clipboard в DM с изоляцией пары и отправлять без подписи.

## Дизайн — [подробная приёмка](docs/design/GUILDCHAT_V1_TODO.md)

- [ ] **DES-02 · P1:** завершить browser/keyboard/screen-reader и zoom приёмку переписки TEXT/DM, включая новые изображения.
- [ ] **DES-03 · P1:** завершить auth/admin states, clipboard/focus и connected VOICE finalization.
- [ ] **DES-04 · P1:** проверить voice/stream states, roster/ник/сигнал и 1/6/20 участников на реальных media-клиентах.
- [ ] **DES-05 · P1:** полный keyboard, focus и screen-reader путь всех панелей и нового image viewer.
- [ ] **DES-06 · P1:** responsive voice/viewer/image и настоящий page zoom 125/150%.
- [ ] **DES-07 · P2:** тексты и фактическое озвучивание ошибок, состояний и действий.
- [ ] **DES-08 · P1:** reproducible matching-state screenshot comparison и исправление отклонений.
- [ ] **DES-09 · P1:** утвердить UX полноразмерного просмотра, отдельного скачивания и вставки изображений из clipboard.

## Проверка и выпуск — [полные протоколы](backlog/VERIFICATION_TODO.md)

- [ ] **QA-03 · P1:** browser privacy/notification/ACL для DM и файлов с третьим аккаунтом.
- [ ] **QA-05 · P1:** trusted browser E2E, OS chooser, image viewer/paste, keyboard/screen reader, zoom и screenshots.
- [ ] **QA-06 · P1:** физический POC-01 игры, голоса и звука трансляции на Windows/macOS с observers.
- [ ] **QA-07 · P1:** POC-02 720p/1080p × 30/60 и причина наблюдаемых 14–15 FPS Android stream после FE-52.
- [ ] **QA-08 · P0:** точный запас attachment volume и reservation под контролируемой нагрузкой, без удаления данных.
- [ ] **QA-09 · P1:** аппаратный load profile 100 участников и до 20 в VOICE-комнате.
- [ ] **QA-10 · P1:** connected-media revocation и replay старых credentials на реальном LiveKit.
- [ ] **QA-12 · P1:** совместимый digest-only rollback с двумя browser-наблюдателями и сверкой volumes.
- [ ] **QA-13 · P1:** Flutter parity, сохранение upload key вне host и физическая Android APK-приёмка; проверить вход двух разных аккаунтов с одного IP и убедиться, что `ACTIVE_VOICE_LEASE`/автоперенос затрагивает только аккаунт-владелец аренды.
- [ ] **QA-14 · P1:** матрица 39 требований, latency/capacity/security evidence и решение о выпуске после остальных PASS.

Порядок: DES-09 → FE-53…55 → QA-05; FE-52 → QA-07; QA-08 вести параллельно как P0; затем физические QA-06/09/10/13, rollback QA-12 и решение QA-14. Успешная сборка или `PASS_SOURCE_ONLY` не закрывает физический/visual гейт.
