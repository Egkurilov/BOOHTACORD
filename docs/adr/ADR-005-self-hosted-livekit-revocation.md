# ADR-005: отзыв доступа self-hosted LiveKit

## Контекст

Deployment использует self-hosted LiveKit node. Удаление подключённого participant необходимо для остановки текущего media, но self-hosted LiveKit не предоставляет Cloud token-revocation service для ранее выданного participant JWT. One-minute credential — только defence in depth и сам по себе не может доказать, что revoked client не выполнит reconnect.

## Решение

Каждая transaction, отзывающая `voice_lease`, вставляет его lease и channel IDs в `voice_sfu_revocations` тем же SQL statement. API worker claim'ит эти metadata-only rows, вызывает private `RoomService.RemoveParticipant` для `voice-lease:<lease-id>` в `voice:<channel-id>` и записывает completion или stable retry code. RoomService credentials генерируются только внутри API container и отправляются только на `http://livekit:7880` в private Docker network.

Перед тем как Caddy forward'ит каждое `/rtc` signal connection или reconnect, он вызывает private API admission endpoint. Endpoint проверяет signed LiveKit token и current lease, issuing session, channel и account state в PostgreSQL. Он не возвращает token detail, а Caddy пропускает access logging для token-bearing signal URI.

Go не проксирует RTP, RTCP или audio/video payloads. LiveKit остаётся media transport; Go владеет только authoritative admission и private RoomService command.

## Последствия

SFU outage не может восстановить admission: lease transaction и signal guard немедленно отклоняют новые и reconnecting media sessions, а durable outbox повторяет participant removal. Response, сообщающий только об отозванных logical leases, не утверждает, что SFU disconnect завершён. POC-03 должен отдельно replay старого API credential и refreshed SDK credential на закреплённом image со вторым observer до прохождения security gate.

## Проверка

Focused Go tests покрывают signed signal admission, отказ expired/overprivileged token, RoomService request scope, durable outbox claiming и retry. POC-03 — единственное evidence для real connected-media termination и replay behaviour.
