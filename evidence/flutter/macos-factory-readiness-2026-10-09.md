# macOS lazy factory readiness (#177)

Development checks PASS; physical Mac acceptance NOT_RUN.
The old public helper called initialize only. It could not exercise the lazy
PeerConnectionFactory path identified by #177. ADR025 records the narrow local
bootstrap exception to the obsolete #178 blanket constraint.

The local plugin API now shares one Mac bootstrap, creates an empty PC with no
ICE servers, closes and disposes it, and only then accepts readiness. Failure is
retriable. Native event cancellation precedes platform disposal. No Room, SDP,
offer/answer, tracks or capture methods run; other native platforms retain prior
initialize behavior. Existing app bootstrap still accepts LiveKit options first.

Red first: missing readiness owner regression. Focused MethodChannel tests now
separately demonstrate initialize/default inventory versus ready/full fixture
inventory; concurrent single-flight, creation failure retry and cleanup-on-close
failure pass. These are actual Dart/native-channel calls with simulated native
responses, not physical ADM evidence.

2026-10-09 checks:
- Plugin bootstrap/disposal: 6 tests PASS.
- App audio inventory, selection, scope, retry and UX: 59 tests PASS.
- No physical Mac, privacy indicator, USB/Bluetooth hotplug, first Join device
  routing or Debug/Profile/Release matrix executed in this Windows workspace.

#184 remains the physical gate; #177 cannot be claimed physically accepted.
Use the installed build/source SHA and record full pre-Join inventory, event/PC
resource cleanup, no microphone indicator, refresh, first Join/reconnect input
and output selection, hotplug and all three build modes. No fixture count proves
an endpoint is audible or a capacity limit is supported.
