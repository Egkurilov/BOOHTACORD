# Бэкенд — оставшаяся работа

Срез: 26.09.2026. Реализация BE-01…BE-18 завершена и перенесена в [DONE](../DONE.md); подробный исходный список BE-01…14 сохранён в истории Git. BE-15 добавлен после фактического измерения production attachment volume, BE-16 — после сообщения пользователя о пустом имени в звонке, BE-17 — после локальной проверки приватного TEXT download, BE-18 — после запроса видеть состав голосовых комнат до входа.

Открытых leaf-задач реализации бэкенда в этом пакете нет. Это не закрывает проверку на реальном LiveKit, нагрузку и приёмку release-кандидата. Конкретные оставшиеся проверки и эксплуатационные действия перечислены в [VERIFICATION_TODO.md](VERIFICATION_TODO.md): QA-03 (DM/ACL browser), QA-08/09 (storage и нагрузка), QA-10 (connected-media revocation и старые credentials), QA-12 (rollback), QA-14 (release matrix). QA-01/04 закрыты trusted GitVerse CI.

Контракт realtime при смене процесса или потере непрерывности журнала требует явный REST resync. Бесшовный replay через перезапуск не заявлен; это не пропуск событий без сигнализации клиенту. Возраст опубликованной истории не запускает удаление файлов: BE-11/12 доступны только как ограниченные операторские команды.

BE-15 экспортирует `voice_platform_attachment_upload_reserved_bytes` из того же admission manager, который обслуживает TEXT и DM uploads. Это позволяет QA-08 измерить in-flight bytes после развёртывания нового API; текущий production image до rollout эту метрику не содержит.

BE-16 берёт `users.display_name` при выдаче каждой active voice lease credential и подписывает LiveKit JWT `name`; новые подключения получают имя, а уже подключённым требуется переподключение. [Source evidence](../evidence/design/voice-participant-display-name-2026-09-25-001.json) PASS_NATIVE_ONLY; реальный звонок остаётся DES-04/QA-06.

BE-17 выставляет `Cache-Control: no-store` для защищённого TEXT download при 200 и 404, как уже делает DM download. [Локальная browser/HTTP проверка](../evidence/qa/qa05-valid-png-text-dm-browser-2026-09-26-001.json) обнаружила отсутствие заголовка до исправления; focused Go-тест и OpenAPI закрепляют поведение. QA-05 остаётся открытой до остальных browser/release сценариев.

BE-18 отдаёт авторизованному участнику состав VOICE-комнат из актуального LiveKit snapshot после пересечения с действующими lease/session/account; неудача SFU возвращает 503, не пустой roster. [Go/PostgreSQL/OpenAPI evidence](../evidence/design/voice-roster-stream-alert-2026-09-26-001.json) PASS_LOCAL; двухклиентский реальный LiveKit остаётся QA-06.
