# Разработка iOS-клиента

Документ описывает будущую реализацию в существующем Flutter-проекте, а не наличие готового iOS-приложения. [ADR-006](../../docs/adr/ADR-006-android-client.md) разрешил Android, но не iOS; до начала iOS release work нужно зафиксировать новое продуктовое решение. Web остаётся эталоном поведения; мобильная компоновка и системные разрешения проверяются отдельно.

## 1. Подготовка проекта на macOS

Используйте macOS с установленным Xcode, Flutter iOS toolchain, CocoaPods и физическим iPhone для media-проверок. На Windows можно менять общий Dart-код, но нельзя считать iOS build проверенным. [Flutter iOS setup](https://docs.flutter.dev/platform-integration/ios/setup) описывает требования среды.

В рабочей ветке на Mac после проверки `flutter doctor -v`:

```bash
cd desktop
flutter pub get
flutter create --platforms=ios .
flutter analyze
flutter test
flutter build ios --no-codesign
```

Команда генерации создаст `desktop/ios/`; до коммита просмотрите diff всех платформенных файлов и не перезаписывайте существующие Android/macOS/Windows настройки. Укажите утверждённый bundle ID, signing team и deployment target по совместимости закреплённых `livekit_client`, `flutter_webrtc` и других plugins. На устройстве: `flutter run -d <ios-device-id>`. Release archive/IPA собирайте только после проверки signing и [acceptance](ACCEPTANCE.md); Flutter описывает архивирование в [iOS deployment](https://docs.flutter.dev/deployment/ios).

## 2. Минимальные платформенные интеграции

| Срез | Реализация и критерий |
| --- | --- |
| Идентичность | Использовать текущий [`ApiClient`](../../desktop/lib/src/services/api_client.dart) и secure session cookie. Проверить iOS Keychain-поведение `flutter_secure_storage`, logout/401, `SameSite`/CSRF/Origin на живом API; без bearer/OAuth и без ослабления TLS. Если native headers не проходят backend policy, оформить контрактное решение и тесты, а не обход. |
| Навигация | Привести размеры, safe areas, клавиатуру, системный Back/gesture, VoiceOver и Dynamic Type к web сценариям с мобильной компоновкой. Проверить вложения, защищённый preview и picker разрешений в TEXT/DM. |
| Ссылки восстановления | Сначала поддержать безопасное ручное открытие одноразовой ссылки в приложении; автоматические universal links потребуют Associated Domains, серверного association-файла и отдельного e2e. Не помещать reset token в логи/аналитику. |
| Realtime | Same-origin authenticated WebSocket, durable resume cursor, duplicate dedupe и `resync_required` по [контракту](../../contracts/mobile-client-contract.md). В общем Flutter-коде пока есть переподключение/dedupe и обработка `resync_required`, но `after` cursor не передаётся: это отдельная доработка, которую нельзя считать готовой из Android-исходников. Reconnect WebSocket не должен сбрасывать здоровый voice call. |
| Voice | Voice lease → short-lived LiveKit credential → room. Проверить mic permission, mute/deafen, аудиомаршруты (speaker/earpiece/Bluetooth), interruption, background/foreground и отзыв lease. Добавлять лишь необходимые `Info.plist` privacy descriptions/background capabilities. |
| Screen viewing | Подписка только на выбранный stream, защищённые participant labels, полноэкранный просмотр, no-audio и receiver diagnostics. Проверить поведение на iPhone и, если выбран, iPad. |
| Screen publishing | Отдельный технический spike: подтвердить поддержку закреплёнными Flutter/LiveKit plugins и версиями iOS, выбрать in-app или full-device capture, системный permission flow и нужную extension/App Group только если она действительно требуется. Проверить остановку ОС, отзыв track/lease и отсутствие утечки кадра после stop. [LiveKit screen-share guidance](https://docs.livekit.io/transport/media/screenshare/) описывает различия типов захвата. Системный звук не обещать без реализованного пути и измерений. |
| Администрирование | Показывать функции только по роли и всё равно полагаться на server-side ACL. Не добавлять admin bypass для DM. |

## 3. Порядок реализации

1. Создать и зафиксировать iOS runner, signing/permissions baseline и сборку на Mac; CI должен явно проверять iOS source build, когда доступен macOS runner.
2. Довести auth/cookie, topology, TEXT и DM до живого API с отрицательными ACL/401/CSRF сценариями.
3. Довести voice receive/send, route changes, reconnect/revocation и interruption на двух физических клиентах.
4. Подтвердить screen viewing, затем отдельно решать screen publishing после SDK spike.
5. Провести визуальную/доступную приёмку, замеры медиа и релизный gate по [ACCEPTANCE.md](ACCEPTANCE.md); обновить [parity map](../../docs/flutter-web-parity.md) и версию только после доказательств.

Не добавляйте push notifications, camera, recording, group DM, federation или собственный media proxy в рамках этого плана. API, storage и LiveKit management остаются приватными; содержимое DM, cookies и media credentials не попадают в diagnostic/evidence.
