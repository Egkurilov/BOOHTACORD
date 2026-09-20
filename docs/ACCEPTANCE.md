# Приёмка и release gates

## Функциональные gates

- Неаутентифицированный посетитель не может читать history, membership или attachments и получать media credentials.
- `MEMBER` может зарегистрироваться, войти в public channels, voice и один DM 1:1; `ADMINISTRATOR` управляет только задокументированными guild resources и никогда не читает DM третьей стороны по роли.
- Voice user может явно выбрать устройства, слушать после отказа в доступе к microphone, mute/deafen, reconnect после краткого network break и transfer единственного voice lease.
- Screen sharing использует browser picker, отдельные tracks и один выбранный remote stream; остановка или переключение stream не создаёт дублирующий audio.
- Attachments ограничены 25 000 000 bytes, а каждый download повторно авторизуется. У опубликованных chat/attachments нет automatic retention expiry.

## Измеряемые gates

В выбранной нормальной сети зафиксируйте p95: voice join после разрешений ≤3 s, доставка message/WebSocket ≤500 ms, переключение выбранного stream ≤2 s и voice reconnection ≤10 s. Обязательный ACL test suite не должен иметь подтверждённых нарушений. POC-01 подтверждает Windows/macOS game audio/capture/voice без loop. POC-02 подтверждает claims о Chrome/OS/video profiles. POC-03 подтверждает media revocation/replay behaviour.

Load gate отдельно измеряет 100 одновременных guild voice participants, до 20 в voice channel и до одного screen source на participant без искусственной product stream quota. Transport-only load generator не доказывает capture quality или поведение macOS.

## Решение о выпуске

Release требует всех обязательных automated checks, актуального Windows/macOS hardware evidence, capacity evidence на выбранной инфраструктуре, CI/CD deploy/smoke evidence и отсутствия нерешённого security или согласованного user-scenario blocker. Для production deploy дополнительно нужны предоставленные владельцем repository, registry, domain, DNS/TLS, SSH и network inputs. Зелёные UI mocks или lint не закрывают media/capacity/security gate.
