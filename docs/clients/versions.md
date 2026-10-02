# Версии клиентов и статус возможностей

Версию читайте в манифесте конкретной ревизии. Для точного состава поставки
используйте commit SHA и `artifact-manifest.json`; наличие новой версии в
исходниках не означает публикацию или прохождение физической приёмки.

| Клиент | Источник версии | Значение | Что оно означает |
| --- | --- | --- | --- |
| Web | [`clients/web/package.json`](../../clients/web/package.json) | Поле `version` | Production определяется точным commit SHA/OCI digest |
| Android | [`clients/flutter/pubspec.yaml`](../../clients/flutter/pubspec.yaml) | Поле `version` | `versionName` и build number; split APK добавляет ABI-код |
| iOS | [`clients/flutter/pubspec.yaml`](../../clients/flutter/pubspec.yaml) | Поле `version` | Build name/number передаются в Xcode; публикация и приёмка отдельные |

`/api/v1` — версия серверного HTTP-контракта, не версия приложения. Совместимость проверяется вместе с [`openapi.yaml`](../../contracts/openapi.yaml), [`realtime.schema.json`](../../contracts/realtime.schema.json) и [mobile contract](../../contracts/mobile-client-contract.md). Не выводите номер релиза из даты или одного зелёного CI.

## Правила изменения версий

1. Сохраняйте один проверяемый источник версии на build root: `package.json` для web, `pubspec.yaml` для Flutter. Android и iOS runners используют общий Dart-код, но их публикации и приёмка независимы.
2. При пользовательском релизе записывайте commit SHA, версию, платформу/архитектуру, hash артефакта, контрактную ревизию и ссылку на evidence. Для web сохраняйте OCI digest; для Android — подписанный APK/AAB, для iOS — подписанный archive/IPA после утверждения платформы.
3. Меняйте build number при новой Android/iOS сборке, распространяемой тестировщикам или пользователям; release name меняйте при согласованном изменении продукта. Не переписывайте уже выпущенный артефакт тем же номером.
4. Версия Flutter не является заявлением о полной Flutter ↔ web parity. Открытые gaps и проверки поддерживаются в [parity map](../flutter-web-parity.md) и [TODO](../../TODO.md).

## Что реализовано в исходниках

| Область | Web | Android Flutter | iOS |
| --- | --- | --- | --- |
| Авторизация, профиль, topology, TEXT/DM, поиск, вложения | Есть | Есть в общем Flutter-коде | Общий Flutter-код и iOS runner есть; на устройстве пока подтверждён экран входа |
| Мобильный старт и жесты | Не применяется | [Стартовая шторка с единым списком текстовых и голосовых каналов, прямой вход в голосовую комнату, ответ, обновление истории и плавные переходы](ios/GESTURES.md) в общем Flutter-коде | Код и widget-тесты есть; ручная проверка на iPhone открыта |
| Голос, prejoin roster, настройка аудио, просмотр экрана | Есть | Есть в общем Flutter-коде | Платформенное поведение не проверено |
| Публикация экрана | Browser capture UI | Android native flow в исходниках | In-app capture в исходниках; фактический захват на устройстве не проверен |
| Административные действия | По серверной роли | UI в общем Flutter-коде | iOS-сборка есть; ACL-приёмка не проводилась |

Таблица означает наличие кода, а не успешную физическую приёмку. Подробности реализованного и открытого — [Flutter ↔ web parity](../flutter-web-parity.md), [DONE](../../DONE.md), [backlog](../../TODO.md) и [evidence](../../evidence/README.md).
