# TODO — BOOHTACORD

Сверено 25 сентября 2026 года с текущим рабочим деревом, включая незакоммиченные изменения.
Основание: утверждённое ТЗ, backlog/tasks.yaml, действующие ADR, код и evidence.

**Реализованное вынесено в [DONE.md](DONE.md).** Результаты ревью — в [отчёте](docs/reviews/2026-09-24-functionality.md).
Наличие реализации не означает приёмку на PostgreSQL, в браузере или на физическом оборудовании.

## Как пользоваться списком

- Здесь только оставшаяся работа. Тематические списки содержат точки входа, зависимости и критерии закрытия.
- P0 — восстановить проверки/устранить блокер; P1 — обязательный пользовательский сценарий; P2 — дальнейшее доведение и эксплуатация.
- BE-*, FE-*, DES-*, QA-* — конкретные задачи; T-* в YAML остаются исходными пакетами требований, а не заявлениями о полной готовности.
- T-051 обозначает Android по ADR-006. Accessibility относится к T-050 / DES-05 / QA-05; прежний конфликт ID устранён.
- После выполнения переносить конкретный результат в DONE с источником проверки. Hardware/release gates закрываются отдельно.

## Сначала

- [ ] **QA-08 · P0:** измерить attachment volume на хосте deployment; [проверка 25.09](evidence/capacity/qa08-attachment-volume-2026-09-25-001.json) подтверждает код порога и HTTP 507, но actual volume недоступен из этой среды. Исторические 9% root и локальные 31,4% C: не являются его показателем.

## Бэкенд

BE-01…14 реализованы и вынесены в [DONE.md](DONE.md). [BACKEND_TODO.md](backlog/BACKEND_TODO.md) фиксирует оставшиеся ограничения реализации; интеграционная, media и release-приёмка остаются в QA ниже.

## Фронтенд

Детали: [FRONTEND_TODO.md](backlog/FRONTEND_TODO.md).

- [ ] **FE-08:** DM retry с сохранением client_message_id.
- [ ] **FE-09:** имена и аватары авторов вместо UUID в сообщениях и ответах.
- [ ] **FE-10–14:** название/порядок категорий, название/перенос/порядок/архивирование каналов и закрытие voice.
- [ ] **FE-15/16:** unread/mentions в навигации и уведомления после разрешения.
- [ ] **FE-17:** DM attachment picker, прогресс/ошибки, download и preview.
- [ ] **FE-18:** привязка draft/reply/attachments к беседе при переключении.
- [ ] **FE-19:** сохранение текста редактора при 409 или ошибке запроса.
- [ ] **FE-20:** единый подсчёт Unicode-символов в формах и API.
- [ ] **FE-21 · P2:** переход из поиска к найденному сообщению и его контексту.

## Дизайн

Детали и исходные DS-T01…12: [GUILDCHAT_V1_TODO.md](docs/design/GUILDCHAT_V1_TODO.md).

- [ ] **DES-01:** сверить 40 компонентов с исходным контрактом и ADR-008/009.
- [ ] **DES-02:** состояния переписки: длинная история, reply/edit conflict, retry, unread/mention, upload.
- [ ] **DES-03:** logout/reset/топология и подтверждения опасных действий.
- [ ] **DES-04:** listener, mute/deafen, reconnect, transfer/kick, нет аудио/кадра.
- [ ] **DES-05:** focus, клавиатура, доступные dialogs/drawers и возврат фокуса.
- [ ] **DES-06:** 1440/1280/1024 CSS px и zoom 125%/150%.
- [ ] **DES-07:** единые русские названия, подписи и честные обозначения измерений.
- [ ] **DES-08:** screenshot comparison проверяемой сборки и evidence.

## Интеграция, эксплуатация и выпуск

Детали: [VERIFICATION_TODO.md](backlog/VERIFICATION_TODO.md).

- [ ] **QA-01–04:** PostgreSQL integration, auth/admin races, storage/DM privacy, миграции и CI.
- [ ] **QA-05:** authenticated browser E2E, визуальная/клавиатурная приёмка.
- [ ] **QA-06/07:** POC-01 Windows + Apple Silicon macOS; POC-02, включая расследование низкого FPS.
- [ ] **QA-08/09:** storage preflight и нагрузка 100 участников / до 20 в комнате.
- [ ] **QA-10:** POC-03: connected-media revocation, replay API/SDK credentials, transfer/reconnect.
- [ ] **QA-11/12:** действующая схема GitVerse delivery, checks и проверка maintenance/rollback.
- [ ] **QA-13:** Android: release-подпись, физические device tests и отдельный parity backlog.
- [ ] **QA-14:** финальная матрица требований, качества и release evidence.

Порядок: оставшиеся FE/DES leaf-задачи → integration/E2E → приёмка кандидата.
Аппаратные POC и capacity остаются обязательными для release; unit/build/health их не заменяют.

Границы: одна гильдия, Vue/Go/PostgreSQL/LiveKit, DM только для двух участников; без камеры, записи, групповых DM, backups, TTL опубликованной истории и Redis по умолчанию. Android разрешён ADR-006; iOS/background push не добавляются.
