# Roster production probe chronology

Supplement to `production-readonly-2026-10-08.md`; its original observations are
historical, not a current unresolved RCA claim.

1. At 20:11 UTC the incident packet proved API namespace DNS SERVFAIL for
   `livekit`, while edge proxy resolution and signed private-IP requests worked.
   The SFU private endpoint lacked the `livekit` alias.
2. Root's successful proxy probe at 20:24 UTC tested the edge path and therefore
   did not disprove the API DNS fault.
3. The separate production repair restored the private alias at 20:28 UTC.
4. Root's exact Go snapshot probe at approximately 20:35 UTC ran **after repair**.
   Its success proves the repaired API namespace path at that instant.
5. Master now contains the private-path release preflight and repair deployment
   evidence. Development #266 and #267 were closed with remaining acceptance
   explicitly transferred to #272.

Authoritative incident records:

- [Confirmed RCA](../backend/vr01-roster-sse-production-rca-2026-10-08-001.json)
- [Repair and deployed release](../backend/vr02-roster-sse-private-dns-repair-2026-10-08-001.json)

Authenticated end-user REST/SSE, correlation with the original screenshot and
physical clients remain **NOT_RUN**. Successful dependency probes do not prove
those acceptance steps.
