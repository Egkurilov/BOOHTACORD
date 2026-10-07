# Screen-share real SDK/SFU smoke

The web native gate reuses the repository's pinned, loopback-only LiveKit fixture and Playwright Chromium setup. It mints short-lived synthetic publisher/viewer JWTs in the test process, uses two isolated browser contexts, and publishes only a generated canvas. The evidence attachment follows `contracts/screen-share-sfu-smoke-evidence-v1.schema.json`; it contains numeric counters and whitelisted environment/version fields only.

Headless correctness covers publish, discovery before subscription, explicit select, real SDK outbound/inbound frame counters, decoded presentation, unselect, unpublish, and teardown. The general CI runner does not establish physical capture cadence, hardware FPS/latency quantiles, thermal behavior, or display scanout. Those fields stay `NOT_RUN`/null until a dedicated device run supplies evidence.
