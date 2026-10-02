# Разработка из чистого checkout

1. Клонируйте GitHub-репозиторий и перейдите в его корень.
2. Установите версии из [toolchains.json](../../tools/toolchains.json), Python
   и зависимости `python -m pip install -r tools/requirements-ci.txt`.
3. Добавьте Flutter, Go, Node и PowerShell 7 в PATH; выполните `task doctor`.
4. Выполните `task check:contracts`, `task test:web` и `task test:flutter`.
   Эти команды сами устанавливают зависимости по lockfiles.

Для backend предоставьте отдельную тестовую PostgreSQL 17. Не используйте
рабочую БД. Оба DSN указывают на одну тестовую БД; допустим loopback IP:

```powershell
$env:VOICE_PLATFORM_TEST_DATABASE_URL = 'postgres://voice_platform_test:test-only-password@127.0.0.1:15434/voice_platform_test?sslmode=disable'
$env:TEST_DATABASE_URL = $env:VOICE_PLATFORM_TEST_DATABASE_URL
task test:backend
```

В shell Bash используйте `export` для тех же переменных. Тесты создают
изолированные схемы и очищают их. Gate проверяет major PostgreSQL и запрещает
skips. External PostgreSQL поддерживается; Docker-in-Docker не обязателен.

Web dev server: `npm ci` и `npm run dev` из `clients/web`.
Flutter: `flutter pub get` и `flutter run` из `clients/flutter`.
Platform prerequisites и retained distributions — в [native builds](../clients/native-builds.md).

Для локального полного контура скопируйте `.env.example` в `.env`, заполните
секреты, адрес LiveKit и image names. Production Compose не содержит build;
локальная сборка явно подключает dev overlay:

```sh
docker compose --env-file .env -f deploy/compose.yaml -f deploy/compose.dev.yaml up --build -d
```

Не публикуйте PostgreSQL и management API LiveKit. Проверка health подтверждает
доступность API; media проверяется по отдельным [runbooks](README.md).
