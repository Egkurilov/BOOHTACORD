# Клиенты BOOHTACORD

| Платформа | Раздел | Канонический код | Статус |
| --- | --- | --- | --- |
| Web | [clients/web](web/README.md) | [`frontend/`](../frontend/) | Реализуется и поставляется вместе с сервером |
| Android | [clients/android](android/README.md) | [`desktop/lib/`](../desktop/lib/) + [`desktop/android/`](../desktop/android/) | Flutter runner есть; физическая приёмка продолжается |
| iOS | [clients/ios](ios/README.md) | [`desktop/lib/`](../desktop/lib/) + [`desktop/ios/`](../desktop/ios/) | Runner собран и установлен на iPhone; функциональная приёмка продолжается |
| macOS | [clients/macos](macos/README.md) | [`desktop/lib/`](../desktop/lib/) + [`desktop/macos/`](../desktop/macos/) | GitHub workflow для ZIP-релиза; runner и Developer ID signing/notarization требуют настройки |

Эти папки — отдельные входные разделы платформ, а не копии исходников. Build roots `frontend/` и `desktop/` остаются на прежних путях: на них ссылаются CI, deployment и mobile release checks. iOS и macOS runners находятся в том же Flutter-проекте: `desktop/ios/` и `desktop/macos/`.

Версии и критерии выпуска: [CLIENT_VERSIONING](../docs/CLIENT_VERSIONING.md). Детальная карта реализации и непроверенных сценариев Flutter: [flutter-web-parity](../docs/flutter-web-parity.md).
