# iOS: матрица приёмки

Все пункты ниже имеют статус **NOT_RUN** на 2026-09-28: `desktop/ios/` и iOS-сборки нет. Evidence храните в `evidence/` без персональных сообщений, вложений, cookies, reset/media tokens и пользовательских идентификаторов. `PASS` ставится только после наблюдаемого прогона, а не после переноса Flutter widget tests.

| Gate | Проверка на реальном iPhone | Доказательство |
| --- | --- | --- |
| Build/signing | Debug на поддерживаемом iOS и подписанный test archive; фиксировать Xcode/Flutter/iOS, commit, build name/number, bundle ID | Build log без секретов, hash артефакта, device/OS matrix |
| Auth/session | Регистрация/вход, restart, logout, истечение session, 401, CSRF/Origin rejection, reset link; cookie остаётся в защищённом хранилище | REST status matrix, отсутствие token в URL/logs |
| TEXT/DM ACL | Два аккаунта и сторонний администратор: история, unread, отправка/retry, edit/delete, вложение, preview/download и запрет чужого DM | Endpoint/status trace без содержимого сообщений |
| Realtime | Потеря сети и возврат: resume/dedupe или `resync_required`, privacy адресных DM событий, сохранение живого voice | Event sequence с обезличенными ID, восстановленное состояние |
| Voice | Два клиента: вход/выход, prejoin roster, mute/deafen, PTT где доступен, transfer, kick/logout/lease revocation, reconnect exhaustion | Media/lease trace, слышимость и момент фактического отключения |
| Audio routes | Microphone permission deny/allow, earpiece/speaker, Bluetooth connect/disconnect, звонок/системное interruption, фон/возврат | Матрица маршрутов и слышимости на физических устройствах |
| Screen receive | Выбор потока, first frame, длительное воспроизведение, fullscreen, смена ориентации, stop/rejoin, no-audio, FPS/bitrate/loss diagnostics | Sender/receiver metrics и наблюдаемые кадры; устройство/сеть |
| Screen publish | Только после отдельного SDK spike: разрешение, start/stop, app/background/OS stop, отзыв доступа, no leaked frames, источник/звук согласно принятому scope | Видео/кадры контрольного паттерна, media traces и выбранный capture path |
| UI/a11y | iPhone safe areas, системная клавиатура, VoiceOver, Dynamic Type, ошибки/загрузки/пустые состояния; iPad, если включён в scope | Сопоставимые скриншоты и протокол доступности |
| Release | Security/privacy, серверная совместимость, выбранный набор iOS/устройств, rollback/revocation и owner decision | Подписанный gate record с PASS либо явными BLOCKED/NOT_RUN |

Проверяйте FPS и звук по реальному media-сценарию; эмулятор, unit-тесты или успешная сборка не подтверждают поддержку 30/60 FPS, захват игры или системного звука. За основу формата evidence используйте [общие требования](../../evidence/README.md) и [media POC](../../docs/MEDIA_PROTOTYPE.md). Открытые случаи переносите в [TODO](../../TODO.md) с точным owner и условием закрытия.
