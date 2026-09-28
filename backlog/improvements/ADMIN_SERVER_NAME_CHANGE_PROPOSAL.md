# Админ-панель: смена имени сервера главному администратору

## Текущее состояние

### Где захардкожено
| Файл | Строка | Значение |
|---|---|---|
| `frontend/index.html` | `<title>` | `Voice Platform` |
| `frontend/src/identity/AuthenticationLanding.vue` | `#authentication-title` | `Voice Platform` |
| `frontend/src/notification/notification_delivery.ts` | строка 57 | `runtime.show('Voice Platform', …)` |
| `frontend/src/notification/notification_policy.ts` | `notificationTitle('Voice Platform', …)` | `Voice Platform` |

В backend **никаких** упоминаний "Voice Platform" нет — серверное имя нигде не хранится.

### Существующая инфраструктура
- **Роутинг**: `mux.Handle("POST /api/v1/...", sessionapi.Require(auth)(sessionapi.RequireAdministrator(handler)))` — паттерн уже используется для всех admin-эндпоинтов (`admin_voice_routes.go`, `admin_audit_routes.go`, `admin_account_list_routes.go`).
- **Слои**: `Service → Store → PoolDatabase → pgx/v5`. Миграции — `.sql` файлы в `postgres/migrations/`.
- **Frontend admin UI**: нет отдельной директории `frontend/src/admin/`. Admin-компоненты лежат по модулям, например `frontend/src/channel/AdminChannelRename.vue`.
- **Аудит**: `list_audit_events` — только чтение. **Записи аудита нет** — при смене имени сервера желательно добавить.

## Предлагаемая реализация

### 1. Backend — новый модуль `internal/admin/settings`

Структура (по образцу `rename_channel`):

```
backend/internal/admin/settings/
├── service.go              # Service, Input, Result, ErrInvalidInput
├── api/
│   └── http_handler.go     # GET (read) / PATCH (write)
│   └── http_handler_test.go
└── postgres/
    ├── pool_database.go    # PoolDatabase
    ├── repository.go       # SELECT/UPDATE settings
    ├── repository_test.go
    └── migrations/
        └── 0001_create_settings.sql
```

**Миграция** `0001_create_settings.sql`:
```sql
CREATE TABLE IF NOT EXISTS settings (
    key       TEXT PRIMARY KEY,
    value     TEXT NOT NULL DEFAULT '',
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
INSERT INTO settings (key, value) VALUES ('server_name', 'Voice Platform')
  ON CONFLICT (key) DO NOTHING;
```

**service.go**:
```go
type Input struct {
    ServerName string
}
type Result struct {
    ServerName string
    UpdatedAt  time.Time
}
type Store interface {
    Get(ctx context.Context, key string) (string, error)
    Set(ctx context.Context, key, value string) (time.Time, error)
}
```
Валидация: 1..64 символа, только буквы/цифры/пробелы/дефис/подчёркивание.

**api/http_handler.go**:
- `GET  /api/v1/admin/settings` → `{"server_name": "..."}` (любой auth-пользователь)
- `PATCH /api/v1/admin/settings` → `{"server_name": "New Name"}` → `200` (только admin)

### 2. Backend — регистрация в `cmd/api/main.go`
```go
// GET — для всех аутентифицированных
mux.Handle("GET /api/v1/admin/settings",
    sessionapi.Require(auth)(settingsapi.NewReadHandler(settingsService)))

// PATCH — только admin
mux.Handle("PATCH /api/v1/admin/settings",
    sessionapi.Require(auth)(sessionapi.RequireAdministrator(
        settingsapi.NewHandler(settingsService))))
```

### 3. Backend — OpenAPI
Добавить в `contracts/openapi.yaml`:
```yaml
/api/v1/admin/settings:
  get:
    summary: Get server settings
    responses:
      "200":
        content:
          application/json:
            schema:
              type: object
              properties:
                server_name:
                  type: string
  patch:
    summary: Update server settings
    security:
      - cookieAuth: []
    requestBody:
      required: true
      content:
        application/json:
          schema:
            type: object
            properties:
              server_name:
                type: string
                minLength: 1
                maxLength: 64
    responses:
      "200":
        content:
          application/json:
            schema:
              type: object
              properties:
                server_name:
                  type: string
      "403":
        description: Not an administrator
      "400":
        description: Validation error
```

### 4. Frontend — API-клиент
`frontend/src/api/adminSettings.ts` (по образцу `adminVoice.ts`):
```ts
export interface SettingsPayload {
  server_name: string;
}
export function fetchSettings(signal?: AbortSignal) { … }
export function updateSettings(payload: SettingsPayload, signal?: AbortSignal) { … }
```

### 5. Frontend — UI
**`frontend/src/admin/AdminSettings.vue`** — новый компонент:
- Поле ввода имени сервера
- Кнопка «Сохранить» (PATCH)
- Индикация загрузки / ошибок
- Показывать только если `isAdmin === true`

**Интеграция в существующие места:**
- `frontend/src/identity/AuthenticationLanding.vue` — `h1` подтягивает имя из API
- `frontend/src/notification/notification_policy.ts` — `notificationTitle` получает имя из store
- `frontend/index.html` — `<title>` можно оставить статичным (SSR), или заменить на JS-замену при инициализации
- `frontend/src/notification/notification_delivery.ts` — `runtime.show` получает имя из store

### 6. Frontend — Store
В `frontend/src/store.ts` или отдельном reactive-состоянии:
```ts
export const settings = reactive({
  serverName: 'Voice Platform', // fallback
})
```
При старте приложения — `fetchSettings()` и обновить `settings.serverName`.

### 7. Аудит (опционально, P1)
Записать событие в `audit_events` при PATCH:
```sql
INSERT INTO audit_events (actor_id, action, target, created_at)
VALUES ($1, 'server_name_changed', $2, now());
```

## Порядок работ

| # | Задача | Приоритет |
|---|---|---|
| 1 | Backend: миграция + `settings` модуль (service, postgres, api) | P0 |
| 2 | Backend: роуты в `main.go`, OpenAPI | P0 |
| 3 | Backend: интеграционные тесты (GET/PATCH, 403 для не-админа) | P0 |
| 4 | Frontend: API-клиент + store | P0 |
| 5 | Frontend: `AdminSettings.vue` | P0 |
| 6 | Frontend: интеграция в `AuthenticationLanding`, `notification_policy`, `notification_delivery` | P1 |
| 7 | Аудит при смене имени | P1 |
| 8 | UI-тесты (Playwright) для `AdminSettings.vue` | P2 |

## Что **не** нужно менять
- WebSocket — имя сервера не влияет на WS.
- `backend/internal/identity/*` — роли/сессии не трогаем.
- `frontend/src/notification/` — только замена хардкода на значение из store.

## Критерии готовности
- [ ] `PATCH /api/v1/admin/settings` возвращает 200 для админа, 403 для обычного пользователя
- [ ] `GET /api/v1/admin/settings` доступен любому аутентифицированному
- [ ] Имя сервера отображается в `AuthenticationLanding` и в заголовке уведомлений
- [ ] Миграция применяется без ошибок
- [ ] `contracts/openapi.yaml` валиден
- [ ] Интеграционные тесты backend проходят
