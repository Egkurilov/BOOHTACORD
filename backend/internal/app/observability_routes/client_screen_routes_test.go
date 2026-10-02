package observabilityroutes

import (
	"context"
	"crypto/sha256"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"voice-platform/backend/internal/identity/authenticate_session"
	"voice-platform/backend/internal/identity/session"
	httpmetrics "voice-platform/backend/internal/observability/http_metrics"
)

type screenMetricSessions struct{ role string }

func (fake screenMetricSessions) FindActive(context.Context, [sha256.Size]byte) (authenticatesession.Principal, error) {
	return authenticatesession.Principal{Role: fake.role}, nil
}

func TestClientScreenRoutesRequireSessionAndAdministrator(t *testing.T) {
	issued, err := session.Issue()
	if err != nil {
		t.Fatal(err)
	}
	request := func(method, path, body string) *http.Request {
		r := httptest.NewRequest(method, path, strings.NewReader(body))
		r.AddCookie(&http.Cookie{Name: session.CookieName, Value: issued.Token})
		return r
	}
	for _, test := range []struct {
		role, method, path, body string
		status                   int
	}{
		{"MEMBER", http.MethodGet, "/api/v1/admin/screen-metrics", "", http.StatusForbidden},
		{"ADMINISTRATOR", http.MethodGet, "/api/v1/admin/screen-metrics", "", http.StatusOK},
		{"MEMBER", http.MethodPost, "/api/v1/voice/screen-metrics", `{"platform":"ios_web","direction":"receiver","state":"playing"}`, http.StatusNoContent},
	} {
		mux := http.NewServeMux()
		ConfigureClientScreenRoutes(mux, authenticatesession.New(screenMetricSessions{role: test.role}), httpmetrics.New())
		response := httptest.NewRecorder()
		mux.ServeHTTP(response, request(test.method, test.path, test.body))
		if response.Code != test.status {
			t.Fatalf("%s %s as %s: got %d, want %d", test.method, test.path, test.role, response.Code, test.status)
		}
	}
	mux := http.NewServeMux()
	ConfigureClientScreenRoutes(mux, authenticatesession.New(screenMetricSessions{role: "ADMINISTRATOR"}), httpmetrics.New())
	response := httptest.NewRecorder()
	mux.ServeHTTP(response, httptest.NewRequest(http.MethodGet, "/api/v1/admin/screen-metrics", nil))
	if response.Code != http.StatusUnauthorized {
		t.Fatalf("anonymous status = %d", response.Code)
	}
}
