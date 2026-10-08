# macOS factory readiness implementation plan (#177)

Route small_direct: local flutter_webrtc native factory_bootstrap leaf.
Preservation: other native platforms keep initialize-only behavior; Web remains
no-op. Normal LiveKit initialization options are accepted before process bootstrap.
The current helper is initialize-only; that does not exercise lazy PC creation.

1. Add a real MethodChannel boundary regression that exposes default-only devices
   after initialize and physical fixture devices only after transient PC creation.
2. Add bounded process bootstrap owner with one in-flight operation, success latch,
   retry after creation/cleanup failure and explicit Mac platform gating.
3. Warm only the existing ADM path with empty local PC, close then dispose in
   finally. No offer/answer, descriptions, ICE servers, Room, tracks or capture.
4. Record ADR025 resolving obsolete #178 prohibition with current #177 scope;
   update fork patch inventory and physical QA184 criteria without claiming PASS.
5. Run plugin bootstrap/disposal/init suites, app audio bootstrap tests, native
   analysis and contracts. Hard120 lines/16files, aim100/8.

Stop: source and focused/full regressions pass; actual cold-start Mac, hotplug,
privacy indicator, selected device and all build modes remain physical acceptance.
