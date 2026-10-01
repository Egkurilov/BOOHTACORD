# Клиенты BOOHTACORD

| Платформа | Раздел | Канонический код | Статус |
| --- | --- | --- | --- |
| Web | [clients/web](web/README.md) | [`clients/web/`](../clients/web/) | Реализуется и поставляется вместе с сервером |
| Android | [clients/android](android/README.md) | [`clients/flutter/lib/`](../clients/flutter/lib/) + [`clients/flutter/android/`](../clients/flutter/android/) | Flutter runner есть; физическая приёмка продолжается |
| iOS | [clients/ios](ios/README.md) | [`clients/flutter/lib/`](../clients/flutter/lib/) + [`clients/flutter/ios/`](../clients/flutter/ios/) | Runner собран и установлен на iPhone; функциональная приёмка продолжается |
| macOS | [clients/macos](macos/README.md) | [`clients/flutter/lib/`](../clients/flutter/lib/) + [`clients/flutter/macos/`](../clients/flutter/macos/) | GitHub workflow для ZIP-релиза; runner и Developer ID signing/notarization требуют настройки |

Эти папки — отдельные входные разделы платформ, а не копии исходников. Канонические build roots теперь `clients/web/` и `clients/flutter/`; CI, deployment и mobile release checks используют эти пути. iOS и macOS runners находятся в том же Flutter-проекте: `clients/flutter/ios/` и `clients/flutter/macos/`.

Версии и критерии выпуска: [CLIENT_VERSIONING](../docs/CLIENT_VERSIONING.md). Детальная карта реализации и непроверенных сценариев Flutter: [flutter-web-parity](../docs/flutter-web-parity.md).
