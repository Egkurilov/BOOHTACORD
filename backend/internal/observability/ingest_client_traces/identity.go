package ingestclienttraces

import (
	"net/http"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	correlatesession "voice-platform/backend/internal/observability/correlate_session"
)

func diagnosticIdentity(request *http.Request) (string, string) {
	principal, ok := sessionapi.PrincipalFrom(request.Context())
	if !ok {
		return "", ""
	}
	attrs := correlatesession.Attributes(principal.AccountID, principal.SessionDigest)
	if len(attrs) < 2 {
		return "", principal.AccountID
	}
	return attrs[1].Value.AsString(), principal.AccountID
}
