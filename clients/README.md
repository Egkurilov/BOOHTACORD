# Клиенты BOOHTACORD

| Платформа | Раздел | Канонический код | Статус |
| --- | --- | --- | --- |
| Web | [clients/web](web/README.md) | [`frontend/`](../frontend/) | Реализуется и поставляется вместе с сервером |
| Android | [clients/android](android/README.md) | [`desktop/lib/`](../desktop/lib/) + [`desktop/android/`](../desktop/android/) | Flutter runner есть; физическая приёмка продолжается |
| iOS | [clients/ios](ios/README.md) | [`desktop/lib/`](../desktop/lib/) + [`desktop/ios/`](../desktop/ios/) | Runner собран и установлен на iPhone; функциональная приёмка продолжается |

Эти папки — отдельные входные разделы платформ, а не копии исходников. Build roots `frontend/` и `desktop/` остаются на прежних путях: на них ссылаются CI, deployment и Android release checks. iOS runner находится в том же Flutter-проекте: `desktop/ios/`.

Версии и критерии выпуска: [CLIENT_VERSIONING](../docs/CLIENT_VERSIONING.md). Детальная карта реализации и непроверенных сценариев Flutter: [flutter-web-parity](../docs/flutter-web-parity.md).
