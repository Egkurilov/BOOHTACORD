# Версии клиентов и статус возможностей

**Срез:** 2026-09-28. Таблица фиксирует значения нативных манифестов и состояние исходников на дату проверки, а не опубликованный релиз. Для точного состава сборки используйте commit SHA и evidence конкретной выкладки.

| Клиент | Источник версии | Значение | Что оно означает |
| --- | --- | --- | --- |
| Web | [`frontend/package.json`](../frontend/package.json) | `0.1.0` | Версия npm-пакета; production образ и проверенный deploy идентифицируются точным commit SHA/OCI digest |
| Android | [`desktop/pubspec.yaml`](../desktop/pubspec.yaml) | `1.0.0+1` | Flutter `versionName=1.0.0`, `versionCode=1`; APK/build metadata |
| iOS | [`desktop/pubspec.yaml`](../desktop/pubspec.yaml) | `1.0.0+1` | Локальный iPhone build `CFBundleShortVersionString=1.0.0`, `CFBundleVersion=1`; публикации нет |

`/api/v1` — версия серверного HTTP-контракта, не версия приложения. Совместимость проверяется вместе с [`openapi.yaml`](../contracts/openapi.yaml), [`realtime.schema.json`](../contracts/realtime.schema.json) и [mobile contract](../contracts/mobile-client-contract.md). Не выводите номер релиза из даты или одного зелёного CI.

## Правила изменения версий

1. Сохраняйте один проверяемый источник версии на build root: `package.json` для web, `pubspec.yaml` для Flutter. Android и iOS runners используют общий Dart-код, но их публикации и приёмка независимы.
2. При пользовательском релизе записывайте commit SHA, версию, платформу/архитектуру, hash артефакта, контрактную ревизию и ссылку на evidence. Для web сохраняйте OCI digest; для Android — подписанный APK/AAB, для iOS — подписанный archive/IPA после утверждения платформы.
3. Меняйте build number при новой Android/iOS сборке, распространяемой тестировщикам или пользователям; release name меняйте при согласованном изменении продукта. Не переписывайте уже выпущенный артефакт тем же номером.
4. `1.0.0+1` в Flutter пока не является заявлением о полной Flutter ↔ web parity. Открытые gaps и проверки поддерживаются в [parity map](flutter-web-parity.md) и [TODO](../TODO.md).

## Что реализовано в исходниках

| Область | Web | Android Flutter | iOS |
| --- | --- | --- | --- |
| Авторизация, профиль, topology, TEXT/DM, поиск, вложения | Есть | Есть в общем Flutter-коде | Общий Flutter-код и iOS runner есть; на устройстве пока подтверждён экран входа |
| Жесты мобильного интерфейса | Не применяется | [Навигация, ответ, обновление истории, голосовая панель и просмотр](../clients/ios/GESTURES.md) в общем Flutter-коде | Код и widget-тесты есть; ручная проверка жестов на iPhone открыта |
| Голос, prejoin roster, настройка аудио, просмотр экрана | Есть | Есть в общем Flutter-коде | Платформенное поведение не проверено |
| Публикация экрана | Browser capture UI | Android native flow в исходниках | In-app capture в исходниках; фактический захват на устройстве не проверен |
| Административные действия | По серверной роли | UI в общем Flutter-коде | iOS-сборка есть; ACL-приёмка не проводилась |

Таблица означает наличие кода, а не успешную физическую приёмку. Подробности реализованного и открытого — [Flutter ↔ web parity](flutter-web-parity.md), [DONE](../DONE.md), [backlog](../TODO.md) и [evidence](../evidence/README.md).
