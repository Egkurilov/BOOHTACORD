# IMP-31 / issue 95: restricted network measurements

## Safe observer on the actual Web client

Use a candidate containing `network_diagnostics/bind.ts`. Join a VOICE channel
as a muted listener through the normal UI, with a second authorized participant.
In Chrome DevTools Console obtain a closed anonymous report:

```js
copy(await window.boohtacordVoiceNetworkReport())
```

Collect one report, have the peer send an agreed short signal, wait two seconds,
then collect another. Do not record speech or export `webrtc-internals`, SDK
objects, SDP, candidates, browser HAR or token-bearing error strings. The report
contains only enums and numbers, with no addresses, ports, identifiers or content.
No automatic telemetry upload occurs. `firstRtpObservedMs` requires increasing
audio RTP counters; it is not proof of audible quality. `iceObservedMs` is the
first sampled connected ICE state (250 ms polling during join), not a wire time.
`sdkJoinMs` starts at SDK connect, excluding Go lease/credential request time.
Existing `voice.join` traces cover the separate full application admission.

## Physical matrix (operator-owned, no global firewall changes)

Record exact candidate SHA, client/browser/OS versions, UTC start/end and only
the network class. Keep participant/account IDs and network addresses private.
Use the same two clients and agreed signal on every row, joining manually:

| Row | Condition | Required observations |
|---|---|---|
| home | Actual home network | signal/join/ICE, selected transport, two RTP reports |
| hotspot | Actual mobile hotspot | same reports, subscription and listener confirmation |
| UDP restricted | Operator-controlled isolated network blocks SFU UDP | selected TCP or explicit failure stage |
| TCP restricted | UDP blocked, only approved secure TCP allowed | distinguish signal from ICE/media |
| restore | Remove only the owned restriction, manually rejoin | selected transport and renewed RTP growth |

If a join fails, run the same console command: failed signal leaves `signalMs`
null; established signal followed by failed ICE leaves join/media null. Missing
stats remain null, never zero or a PASS. A manual local leave does not establish
server revocation. Verify that separately using [media-revocation](media-revocation.md).
Do not disconnect or change the workstation network without operator consent.

## Disposable automated lab

On an isolated Linux host with Docker, Python and pinned Node:

```sh
cd clients/web
npm ci
npx playwright install --with-deps chromium
cd ../..
python -m unittest tools.network.restricted.test_sfu
python -m tools.network.restricted.run
```

The matrix uses actual LiveKit 1.13.7 (digest pinned) and two real Chromium
contexts with synthetic mono 48 kHz / 440 Hz and the production Opus profile.
Only loopback ports of a uniquely owned disposable container are published.
Baseline/recovery publish UDP and ICE/TCP; UDP-blocked omits the UDP mapping;
signal-only omits both media mappings; signal-blocked points the client at an
unbound loopback socket. Host/production firewalls and volumes are untouched.
This emulates transport unreachability, not a mobile NAT, HTTP proxy or loss
distribution. Signal is local WS, not a production TLS/admission validation.

Outputs: `.out/restricted-networks/matrix.json` and one closed report per profile.
`measurementGate=PASS` means the expected observation was reproduced;
`connectivity=FAIL` means voice did not connect in that profile. Do not label a
signal-only network supported because the test of its failure passed.
The runner checks UDP/TCP selection and real receiver RTP growth, and removes
each container in `finally`. Unit/build/lab PASS cannot close home/hotspot,
physical QA-06, capacity QA-09 or revocation QA-10.

## TURN decision

Confirm the failure stage on a real affected network before production changes.
An HTTP reverse proxy for `/rtc` forwards signal, not raw TURN/TLS media. A 443
solution needs a separate certificate/hostname and available IP or an explicitly
reviewed L4 topology. Follow the conditional ADR when evidence justifies it.
See [LiveKit ports](https://docs.livekit.io/transport/self-hosting/ports-firewall/)
and [deployment](https://docs.livekit.io/transport/self-hosting/deployment/).
