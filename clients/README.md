# Клиенты BOOHTACORD

| Платформа | Раздел | Канонический код | Статус |
| --- | --- | --- | --- |
| Web | [clients/web](web/README.md) | [`clients/web/`](web) | Реализуется и поставляется вместе с сервером |
| Android | [Android guide](../docs/clients/android.md) | [`clients/flutter/lib/`](flutter/lib) + [`clients/flutter/android/`](flutter/android) | Flutter runner есть; физическая приёмка продолжается |
| iOS | [iOS guide](../docs/clients/ios/README.md) | [`clients/flutter/lib/`](flutter/lib) + [`clients/flutter/ios/`](flutter/ios) | Runner собран и установлен на iPhone; функциональная приёмка продолжается |
| macOS | [macOS guide](../docs/clients/macos.md) | [`clients/flutter/lib/`](flutter/lib) + [`clients/flutter/macos/`](flutter/macos) | GitHub workflow для ZIP-релиза; runner и Developer ID signing/notarization требуют настройки |

Платформенные инструкции находятся в `docs/clients`; код native-клиентов общий. Канонические build roots теперь `clients/web/` и `clients/flutter/`; CI, deployment и mobile release checks используют эти пути. iOS и macOS runners находятся в том же Flutter-проекте: `clients/flutter/ios/` и `clients/flutter/macos/`.

Версии и критерии выпуска: [CLIENT_VERSIONING](../docs/clients/versions.md). Детальная карта реализации и непроверенных сценариев Flutter: [flutter-web-parity](../docs/flutter-web-parity.md).
