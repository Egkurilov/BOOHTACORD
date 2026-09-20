# ADR-003: in-memory limits аутентификации

Статус: принято для single-process MVP.

API применяет fixed-window limit: пять registrations за 15 минут и десять login attempts за пять минут на source IP. Каждый limiter хранит не более 10 000 текущих source windows; expired windows удаляются, а oldest live window вытесняется при достижении capacity. API возвращает `429 RATE_LIMITED` с `Retry-After`, а не молча замедляет или принимает запрос.

Контейнеры API приватны, а Caddy — единственный public ingress, поэтому limiter использует первый valid client address из `X-Forwarded-For`, который устанавливает Caddy; malformed values заменяются непосредственно подключённым address. Документированное поведение Caddy по умолчанию игнорирует входящие forwarded values и устанавливает собственные: <https://caddyserver.com/docs/caddyfile/directives/reverse_proxy>. Если topology получит upstream CDN/load balancer, настройте Caddy trusted proxies до опоры на этот header.

Limits — baseline защиты от abuse, а не distributed quota. Redis намеренно не добавляется. Для будущего horizontal deployment нужна измеренная замена и ADR. Upload имеет отдельный rate-limit leaf, поскольку ему требуется account- и byte-aware enforcement.
