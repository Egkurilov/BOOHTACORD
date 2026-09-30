# macOS-клиент BOOHTACORD

Клиент macOS использует общий Flutter-код из [`desktop/lib/`](../../desktop/lib/) и runner из [`desktop/macos/`](../../desktop/macos/). CI на GitVerse runner с меткой `macos` запускает Flutter tests и analyzer, затем собирает Release для Apple Silicon и Intel.

Релиз публикуется в GitVerse при push тега `macos-vX.Y.Z`, совпадающего с версией в [`desktop/pubspec.yaml`](../../desktop/pubspec.yaml). В релиз попадают ZIP с `BOOHTACORD.app` и файл SHA-256. Для workflow нужен repository secret `RELEASE_API_KEY`, уже используемый Android release workflow.

Текущий workflow проверяет целостность ad-hoc подписи, но не подписывает Developer ID и не выполняет Apple notarization. Gatekeeper может запросить подтверждение запуска. Подписанная и notarized публикация требует отдельного Apple Developer signing setup и остаётся открытой приёмкой; наличие CI-сборки не подтверждает её.
