# Web-клиент

## Где разрабатывать

Канонический проект: [`clients/web/`](.). Стек: Vue 3, TypeScript, Vite, Pinia и LiveKit Client. Текущая версия пакета: `0.1.0` из [`clients/web/package.json`](package.json). Производственный web образ собирается существующим pipeline; этот раздел не меняет его пути.

## Реализованные возможности в исходниках

- Вход, регистрация, выход, завершение сброса пароля, профиль и администрирование по роли.
- Категории и каналы, TEXT и DM с историей, поиском, ответами, правками, удалением, unread/read cursor и упоминаниями.
- Защищённые вложения TEXT/DM, просмотр изображений, загрузка и вставка изображения из буфера.
- Голосовые каналы, список участников до входа, mute/deafen, настройки устройств, reconnect, просмотр и публикация экрана.

Точные состояния и оставшуюся приёмку см. в [карте web ↔ Flutter](../../docs/flutter-web-parity.md), [TODO](../../TODO.md) и [evidence](../../evidence/README.md). Наличие UI и unit-тестов само по себе не доказывает физическое качество media или готовность релиза.

## Локальный запуск и проверки

Из `clients/web/`:

```bash
npm ci
npm run dev
npm test
npm run build
```

Для API/realtime используйте [канонические контракты](../../contracts/openapi.yaml) и [realtime schema](../../contracts/realtime.schema.json). Не обходите серверные ACL и не обращайтесь к private LiveKit management API.
