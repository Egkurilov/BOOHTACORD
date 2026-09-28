# Предлагаемые улучшения — realtime, голос и демонстрация

Это новые кандидатные leaf-задачи; текущие FE-52, QA-06/07/09/10 и DES-04 остаются в [обязательном backlog](../VERIFICATION_TODO.md). `IMP-25/26/30` лишь уточняют их приёмку и учтены в [сводке](../IMPROVEMENTS_TODO.md). Decision gates `IMP-19/28/31` находятся в [OPS_TODO.md](OPS_TODO.md). Для media не подменять аппаратный результат source-тестом.

### IMP-18 · P1 · M — coalescing защищённых refresh
- [ ] Сначала измерить REST requests/event на 1, 20 и 50 ID-only hints при активной/скрытой беседе; затем в соответствующих client stores сделать per-resource single-flight, короткое coalescing-окно и dirty flag после in-flight fetch. Проверить финальную revision, edit/delete старой страницы и отсутствие 50 параллельных GET. **Граница:** session/lease revoke немедленный, body не переносится в WS; QA-03/05/09.

### IMP-20 · P1 · S — независимые состояния связи
- [ ] Развести в UI «Чат обновляется», «Голос подключён/восстанавливается» и «Состав обновлён/недоступен» с возрастом последнего roster и адресным действием восстановления. Проверить разрыв только WS при живом WebRTC, отказ SFU без ложной пустой комнаты и logout/revoke обоих контуров. **Граница:** отсутствие presence snapshot не означает ноль участников.

### IMP-21 · P1 · L — bounded SFU snapshot после измерения
- [ ] **Инструментация source готова:** bounded Prometheus counters/histogram для SFU SnapshotRooms attempts, outcome, duration и room count без ID. Снять RoomService calls/sec и p95 ответа `/voice/participants` при 1/20/100 клиентах; если fan-out подтверждён, добавить process-local single-flight/короткий metadata snapshot с bounded TTL. На **каждый** HTTP ответ повторять session/lease/account ACL и `no-store`. Проверить блокировку/отзыв во время TTL и SFU error → stale/unavailable. Без измерений кэш не включать.

### IMP-22 · P1 · M — локальная проверка звука
- [ ] **Source готов, device-приёмка открыта.** По явному действию показывается локальный уровень выбранного микрофона и короткий тестовый сигнал выбранного output; временные tracks освобождаются при закрытии/смене устройства, без voice lease, записи или отправки медиа на сервер. Осталось физически проверить denial, отсутствие input, OS mute, тихий сигнал, неподдерживаемый output и screen reader на Windows/macOS; локальный уровень не доказывает звук у peer.

### IMP-23 · P1 · M — hotplug, sleep/wake и PTT
- [ ] **Веб-часть частично:** настройки обновляют перечень по `devicechange`, показывают исчезнувший выбранный device и защищены от поздней загрузки списка; live switch вызывается только при активном voice. Проверить Bluetooth/hotplug, sleep/wake, PTT blur, logout во время change, сохранение mute/deafen и звук у реального peer на Windows/macOS. Flutter/Android в этом пакете не менять; его физическая матрица остаётся QA-13.

### IMP-24 · P1 · L — явный transfer между вкладками
- [ ] Показать текущую комнату, последствия «Перенести голос сюда» и владение media-контроллером в пределах origin отдельно от server session/lease. Проверить две вкладки с одной cookie, cancel без изменений, race leave/transfer, ровно один новый lease и запрет старому reconnect. **Зависимость:** QA-02/10 и Flutter reconnect; silent takeover не вводить.

### IMP-27 · P1 · M — честная матрица источников
- [ ] Для Windows/macOS Chrome, Android Chrome, Android Flutter и desktop Flutter показать до picker подтверждённые возможности просмотра, screen video и screen audio; после выбора показать реально полученные tracks и действие при отсутствии audio. Сопоставить с QA-06/07/13 и DES-04; отмена picker не ошибка, unsupported capture не выключает voice/viewer. **Граница:** native share сейчас video-only; game audio — отдельный capability spike/контракт, не обещание кнопкой.

### IMP-29 · P1 · M — диагноз по состоянию, а не одному числу
- [ ] В viewer отличать no first frame, frozen video, no audio track и stale metrics, показывая одно доступное действие; расширенные capture/encoded/decoded/presented counters собирать короткой локальной серией. Для двух receivers экспортировать обезличенный test-run bundle без SDP/IP/ICE/token/user/room/track IDs и содержимого; unknown RTT не превращать в 0. **Зависимость:** FE-52/QA-07; серверный correlation только после отдельного privacy-контракта.

### Связь с действующими media-гейтами

- `IMP-25 → QA-10`: семь причин revoke, observer track end, replay API и SDK credentials.
- `IMP-26 → FE-52/QA-07`: измерить capture, encoded, decoded, presented на движущемся контенте и определить место 14–15 FPS; target не выдавать за факт.
- `IMP-30 → QA-06/07/09`: normal/degraded/recovery для sender и viewer, непрерывность голоса и восстановление без собственного congestion controller до замера.
