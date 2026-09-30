package sessionapi

import (
	"context"
	"crypto/sha256"
	"net/http"
	"net/http/httptest"
	"testing"

	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	"go.opentelemetry.io/otel/sdk/trace/tracetest"
	"voice-platform/backend/internal/identity/authenticate_session"
	"voice-platform/backend/internal/identity/session"
	correlatesession "voice-platform/backend/internal/observability/correlate_session"
)

func TestAuthenticationCorrelatesOnlyVerifiedIdentity(t *testing.T) {
	for _, optional := range []bool{false, true} {
		for _, authenticated := range []bool{false, true} {
			recorder := tracetest.NewSpanRecorder()
			provider := sdktrace.NewTracerProvider(sdktrace.WithSpanProcessor(recorder))
			ctx, span := provider.Tracer("test").Start(t.Context(), "request")
			principal := authenticatesession.Principal{AccountID: "account-1", SessionDigest: sha256.Sum256([]byte("private-token"))}
			auth := authenticatorFunc(func(context.Context, string) (authenticatesession.Principal, error) {
				if !authenticated {
					return authenticatesession.Principal{}, authenticatesession.ErrUnauthenticated
				}
				return principal, nil
			})
			middleware := Require(auth)
			if optional {
				middleware = Optional(auth)
			}
			r := httptest.NewRequest(http.MethodGet, "/protected", nil).WithContext(ctx)
			r.AddCookie(&http.Cookie{Name: session.CookieName, Value: "private-token"})
			r.Header.Set("X-User-ID", "forged-user")
			r.Header.Set("X-Session-ID", "forged-session")
			middleware(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				got, ok := PrincipalFrom(r.Context())
				if ok != authenticated || (ok && got != principal) {
					t.Fatal("authentication behavior changed")
				}
				w.WriteHeader(http.StatusNoContent)
			})).ServeHTTP(httptest.NewRecorder(), r)
			span.End()
			attrs := recorder.Ended()[0].Attributes()
			if authenticated {
				want := correlatesession.Attributes(principal.AccountID, principal.SessionDigest)
				if len(attrs) != 2 || attrs[0] != want[0] || attrs[1] != want[1] {
					t.Fatal("verified user/session attributes missing or overridden")
				}
			} else if len(attrs) != 0 {
				t.Fatal("failed authentication must not attach user identity")
			}
			_ = provider.Shutdown(t.Context())
		}
	}
}
