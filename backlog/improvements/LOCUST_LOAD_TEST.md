# Нагрузочное тестирование — Locust

## Обзор API и ролей

### Эндпоинты (из `contracts/openapi.yaml` + роуты в `cmd/api/main.go`)

| Метод | Путь | Auth | Описание |
|---|---|---|---|
| POST | `/api/v1/auth/session` | — | Сессия (cookie) |
| GET | `/api/v1/auth/session` | cookie | Текущая сессия |
| DELETE | `/api/v1/auth/session` | cookie | Выход |
| GET | `/api/v1/channels` | cookie | Список каналов |
| GET | `/api/v1/channels/{id}` | cookie | Канал |
| GET | `/api/v1/channels/{id}/participants` | cookie | Участники канала |
| POST | `/api/v1/channels` | cookie | Создать канал |
| PATCH | `/api/v1/channels/{id}` | cookie/admin | Переименовать/настроить канал |
| GET | `/api/v1/messages` | cookie | Сообщения |
| POST | `/api/v1/messages` | cookie | Отправить сообщение |
| GET | `/api/v1/admin/settings` | cookie | **Новый**: получить настройки |
| PATCH | `/api/v1/admin/settings` | cookie+admin | **Новый**: сменить имя сервера |
| POST | `/api/v1/admin/accounts/{id}/voice-kick` | cookie+admin | Кик из голосового канала |
| GET | `/api/v1/admin/audit-events` | cookie+admin | Аудит |
| POST | `/api/v1/ws` | cookie | WebSocket (отдельный транспорт) |

### Роли
- **RegularUser** — аутентифицированный пользователь: каналы, сообщения
- **AdminUser** — `is_admin: true`: всё выше + admin-эндпоинты

## Локальный запуск

```bash
# 1. Поднять инфраструктуру
cd /projects/BOOHTACORD
docker compose up -d postgres redis

# 2. Применить миграции
# (см. README, обычно автоматически или через make migrate)

# 3. Поднять backend
cd backend && go run ./cmd/api

# 4. Поднять frontend (не обязателен для load test API, но для E2E)
cd frontend && npm run dev
```

## Locust-скрипт

```python
# loadtest/locustfile.py
import json
import random
import time

from locust import HttpUser, task, between, events
from locust.env import Environment


class VoicePlatformUser(HttpUser):
    """Обычный пользователь: каналы + сообщения."""

    wait_time = between(0.5, 2.0)
    host = "http://localhost:8080"

    def on_start(self):
        """Аутентификация: создать сессию."""
        # Создаём тестового пользователя через админ-API или используем фиксированного
        # Для load test лучше использовать существующего пользователя
        self.login()

    def login(self):
        """Создать сессию."""
        # ВАЖНО: реальное auth-механизм зависит от реализации.
        # Здесь — упрощённый вариант: используем cookie от существующей сессии.
        # В реальном сценарии: POST /api/v1/auth/session с credentials.
        # Для load test лучше:
        #   1. Создать фиксированного пользователя в БД
        #   2. Получить cookie через auth endpoint
        #   3. Использовать cookie в каждом запросе

        # Упрощённый вариант: используем фиксированный cookie
        # В реальном сценарии это будет:
        #   resp = self.client.post("/api/v1/auth/session", json={...})
        #   self.client.cookies = resp.cookies
        pass

    @task(10)
    def list_channels(self):
        self.client.get("/api/v1/channels")

    @task(5)
    def get_channel(self):
        self.client.get("/api/v1/channels/1")

    @task(3)
    def list_participants(self):
        self.client.get("/api/v1/channels/1/participants")

    @task(8)
    def list_messages(self):
        self.client.get("/api/v1/messages?channel_id=1&limit=20")

    @task(4)
    def send_message(self):
        self.client.post("/api/v1/messages", json={
            "channel_id": 1,
            "body": f"Load test message {random.randint(1, 10000)}",
        })


class AdminUser(VoicePlatformUser):
    """Администратор: все задачи обычного + admin-эндпоинты."""

    wait_time = between(1.0, 3.0)

    @task(1)
    def get_settings(self):
        self.client.get("/api/v1/admin/settings")

    @task(1)
    def update_settings(self):
        self.client.patch("/api/v1/admin/settings", json={
            "server_name": f"Voice Platform {random.randint(1, 99)}",
        })

    @task(1)
    def list_audit(self):
        self.client.get("/api/v1/admin/audit-events?limit=10")

    @task(1)
    def kick_voice_participant(self):
        self.client.post("/api/v1/admin/accounts/1/voice-kick", json={})


# === Сценарии ===

# Сценарий 1: Только обычные пользователи (50% нагрузки)
# locust -f loadtest/locustfile.py --users=100 --spawn-rate=10 --host=http://localhost:8080

# Сценарий 2: 90% обычные + 10% админы
# Для этого нужно переключать классы пользователей.
# В Locust это делается через `--class` или через custom shape.

# Сценарий 3: Spike test — резкое увеличение нагрузки
# locust -f loadtest/locustfile.py --users=50 --spawn-rate=5 --run-time=300s

# Сценарий 4: Sustained load — длительная нагрузка
# locust -f loadtest/locustfile.py --users=200 --spawn-rate=1 --run-time=3600s
```

## Запуск Locust

### 1. Установка

```bash
pip install locust
```

### 2. Быстрый запуск (headless, без UI)

```bash
# 100 пользователей, 10/sec spawn, 5 минут
locust -f loadtest/locustfile.py \
  --headless \
  --users=100 \
  --spawn-rate=10 \
  --run-time=300s \
  --host=http://localhost:8080
```

### 3. С Web UI

```bash
# Откроется http://localhost:8089
locust -f loadtest/locustfile.py \
  --users=100 \
  --spawn-rate=10 \
  --host=http://localhost:8080
```

### 4. Сохранение результатов

```bash
# JSON
locust -f loadtest/locustfile.py \
  --headless \
  --users=100 \
  --spawn-rate=10 \
  --run-time=300s \
  --host=http://localhost:8080 \
  --json=loadtest/result.json \
  --html=loadtest/report.html

# CSV (поэтапно)
locust -f loadtest/locustfile.py \
  --headless \
  --users=100 \
  --spawn-rate=10 \
  --run-time=300s \
  --host=http://localhost:8080 \
  --csv=loadtest/result
```

## Нагрузочные профили

| Профиль | Пользователи | Spawn | Длительность | Цель |
|---|---|---|---|---|
| Smoke | 10 | 5 | 60s | Базовая работоспособность |
| Baseline | 50 | 5 | 5m | Номинальная нагрузка |
| Sustained | 200 | 1 | 1h | Долгосрочная стабильность |
| Spike | 50→500 | 50 | 10m | Пиковая нагрузка |
| Endurance | 100 | 1 | 24h | Выявление утечек памяти |

## Метрики для отслеживания

### Backend
- **HTTP**: P50/P95/P99 latency, error rate (5xx), throughput (req/s)
- **Prometheus** (`/metrics`):
  - `http_request_duration_seconds` — latency по эндпоинтам
  - `http_requests_total` — throughput
  - `process_resident_memory_bytes` — память
  - `go_routines` — goroutines (утечки)
  - `pgx_pool_acquire_duration` — Postgres pool
- **Postgres**:
  - `pg_stat_statements` — медленные запросы
  - `pg_stat_activity` — active connections
  - `pg_locks` — deadlocks

### Frontend (опционально)
- LCP, FCP, TTI (через Lighthouse в CI)

## Критерии успешного тестирования

| Метрика | Порог |
|---|---|
| P95 latency (API) | < 200ms |
| P99 latency (API) | < 500ms |
| Error rate | < 0.1% |
| Throughput (API) | > 500 req/s |
| Memory growth | < 50MB за 1h |
| Goroutines | Стабильно (без утечек) |
| DB connections | < 50 active |

## Известные ограничения

1. **Auth**: скрипт использует фиксированные сессии. Для реалистичного теста нужно:
   - Создать фиксированного пользователя в БД
   - Реализовать `on_start()` с реальным auth flow
   - Для admin — отдельного админ-пользователя

2. **WebSocket**: Locust не поддерживает WS нативно. Для WS-load test:
   - Использовать `locust-websocket` (если существует) или
   - Отдельный скрипт на `python-websocket-client`

3. **Redis cache**: при высокой нагрузке cache hit rate должен быть > 90% для channel list

4. **Масштабирование**: Locust-агент запускается на одном хосте. Для >1000 VU:
   - Запустить несколько `locust --worker`
   - Один `locust --master`
