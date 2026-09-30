# macOS-клиент BOOHTACORD

Клиент macOS использует общий Flutter-код из [`desktop/lib/`](../../desktop/lib/) и runner из [`desktop/macos/`](../../desktop/macos/). Ручной GitHub Actions workflow на runner с метками `self-hosted`, `macos` запускает Flutter tests и analyzer, затем собирает Release для Apple Silicon и Intel. До регистрации GitHub runner запуск не подтверждён.

Релиз публикуется в GitHub через ручной запуск [macOS Release](../../.github/workflows/macos-release.yaml) от тега `macos-vX.Y.Z`, совпадающего с версией в [`desktop/pubspec.yaml`](../../desktop/pubspec.yaml). В релиз попадают ZIP с `BOOHTACORD.app` и файл SHA-256. Workflow использует встроенный `GITHUB_TOKEN` с правом `contents: write`.

Текущий workflow проверяет целостность ad-hoc подписи, но не подписывает Developer ID и не выполняет Apple notarization. Gatekeeper может запросить подтверждение запуска. Подписанная и notarized публикация требует отдельного Apple Developer signing setup и остаётся открытой приёмкой; наличие CI-сборки не подтверждает её.
