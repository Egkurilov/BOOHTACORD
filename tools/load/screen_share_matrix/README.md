# Screen-share load matrix v1

`profiles-v1.json` is the versioned SS-18 scenario catalog. Compile a deterministic
room and selected-subscription plan without opening sockets:

```powershell
python -m tools.load.screen_share_matrix.planner --profile L04
```

The output deliberately remains `NOT_RUN`. It is a topology/phase manifest, not
a media generator or a capacity result. Current repository CI has a one-publisher,
one-viewer headless LiveKit correctness smoke and the backend API load harness; it
does not support 10–30 simultaneous media clients with a measured generator budget.
Do not turn generated canvas traffic, API load, `getSettings()`, or local frames into
claims about SFU capacity or physical capture/decode/presentation. `generator`,
`sfu`, `physical_decode`, `voice`, and overall outcome are separate evidence gates.

Before connecting this matrix to a dedicated isolated deployment, provide a bounded
scalable LiveKit-client generator, per-generator CPU/network sampling, SFU resource
metrics, paired physical sender/viewer control from #173, approved #157 budgets,
and teardown/stop controls. Run no media matrix against production. L09 keeps sender
uplink and one receiver downlink impairments separate; L10 is a two-hour soak plan.
