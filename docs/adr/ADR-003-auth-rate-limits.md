# ADR-003: In-memory authentication rate limits

Status: accepted for the single-process MVP.

The API applies a fixed-window limit of five registrations per 15 minutes and ten login attempts per five minutes per source IP. Each limiter retains at most 10,000 current source windows; expired windows are removed and the oldest live window is evicted at capacity. The API returns `429 RATE_LIMITED` with `Retry-After` instead of silently slowing or accepting the request.

API containers are private and Caddy is the only public ingress, so the limiter uses the first valid `X-Forwarded-For` client address that Caddy sets; malformed values fall back to the directly connected address. Caddy’s documented default ignores incoming forwarded values while setting its own: <https://caddyserver.com/docs/caddyfile/directives/reverse_proxy>. If the topology gains an upstream CDN/load balancer, configure Caddy trusted proxies before relying on that header.

The limits are an anti-abuse baseline, not a distributed quota. Redis is deliberately not introduced. A later horizontal deployment requires a measured replacement and ADR. Upload has its own rate-limit leaf because it needs account- and byte-aware enforcement.
