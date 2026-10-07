# Public API contract viewer

From the repository root:

```powershell
python -m pip install -r tools/verify/openapi_parity/requirements.txt
python -m tools.verify.openapi_parity.lint
python -m tools.verify.openapi_parity.validate
python -m tools.contracts.swagger_view.serve --port 8081
```

Open <http://127.0.0.1:8081/>. Stop with Ctrl+C. The server binds only to
loopback and serves only its HTML and the exact `contracts/openapi.yaml` bytes
as JSON. The contract uses valid JSON syntax, which is also YAML syntax.
Swagger UI **5.31.0** is pinned; its JavaScript/CSS load from jsDelivr, so first
use requires network access. This UI supports the OpenAPI 3.1 contract.

The viewer is a reference with request execution disabled. It does not proxy
the API or create an anonymous API access path. A browser cannot set a Cookie
or Origin header through Swagger authorization. The server requires an opaque
`vp_session` cookie (`Secure`, `HttpOnly`, `SameSite=Lax`, `Path=/`) and the exact
configured `PUBLIC_ORIGIN` for every public mutation, including anonymous login,
registration, logout and password-reset completion. A localhost HTTP viewer
cannot act as an authenticated production client. Actual request execution
requires a UI hosted on the deployment origin and a normal login there; any
such deployment is separate from this local viewer. Native clients must use
the same cookie and Origin contract. IDs and diagnostic headers grant no ACL.

Ten operations accept anonymous requests, including idempotent logout and an
optional-cookie session probe. All other operations require the cookie and
their normal server ACL. The three private scrape/LiveKit hooks are documented
under `x-private-route-exclusions`; they do not appear as client operations.

CI contracts installs the pinned lint dependency and invokes the parity tests,
OpenAPI 3.1 lint and native-route checker through
`tools/verify/contracts/verify-contracts.ps1`. Route extraction uses the Go AST,
resolves middleware variables and topology handler bindings, and follows native
composition imports. Unsupported dynamic route patterns fail the gate. Request
parameter checks inspect exact handler constructors and their local helpers.
Standard HTTP transport headers and optional diagnostic middleware headers are
described below rather than treated as operation-specific business parameters.

Tracing may consume W3C `traceparent`/`tracestate`. An authenticated request may
carry `X-Telemetry-Session`, `X-App-Visit`, `X-App-Flow`, `X-App-Flow-Name`,
`X-App-Attempt` and `X-App-Media-Session`; invalid metadata is ignored by the
binding middleware. The relay additionally checks its explicit session guard.
Realtime query fallbacks are declared directly on the upgrade operation.

Responses receive a fresh server-generated `X-Request-ID`; incoming IDs are
ignored. Failed ID generation emits an empty 500 before setting the header.
JSON errors vary: full `Error` details, compact code-only `Error`, flat update
errors, and empty/text responses are all intentional wire shapes. A session
lookup failure may emit an empty 500 even when the handler's own 500 is JSON.

Automated validation does not prove a visual browser review or live production
cookie/media behavior. The issue evidence keeps those acceptance states explicit.
