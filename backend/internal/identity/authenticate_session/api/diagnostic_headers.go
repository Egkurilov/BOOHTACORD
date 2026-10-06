package sessionapi

import (
	"context"
	"net/http"
	"voice-platform/backend/internal/identity/authenticate_session"
	bindflow "voice-platform/backend/internal/observability/bind_flow"
	correlatesession "voice-platform/backend/internal/observability/correlate_session"
)

func authenticatedContext(writer http.ResponseWriter, request *http.Request, principal authenticatesession.Principal) context.Context {
	ctx := WithPrincipal(request.Context(), principal)
	attrs := correlatesession.Attributes(principal.AccountID, principal.SessionDigest)
	if len(attrs) > 1 {
		sessionID := attrs[1].Value.AsString()
		writer.Header().Set("X-Telemetry-Session", sessionID)
		writer.Header().Set("X-Telemetry-Schema", "1")
		headers := request.Header
		if request.URL.Path == "/api/v1/realtime" {
			headers = headers.Clone()
			query := request.URL.Query()
			for name, key := range map[string]string{"X-Telemetry-Session": "telemetry_session", "X-App-Visit": "visit", "X-App-Flow": "flow", "X-App-Flow-Name": "flow_name", "X-App-Attempt": "attempt"} {
				if headers.Get(name) == "" {
					headers.Set(name, query.Get(key))
				}
			}
		}
		ctx = bindflow.Bind(ctx, headers, sessionID)
	}
	return ctx
}
