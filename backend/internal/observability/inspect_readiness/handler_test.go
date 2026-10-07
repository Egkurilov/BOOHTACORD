package inspectreadiness

import (
	"encoding/json"
	"errors"
	"net/http/httptest"
	"strings"
	"testing"
	"voice-platform/backend/internal/health"
	authenticatesession "voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
)

func TestReadinessDeniesNonAdministratorsBeforeProbing(t *testing.T) {
	// Nil dependencies deliberately fail if authorization accidentally probes them.
	handler := Handler(New(nil, nil, nil, nil))
	for _, role := range []string{"", "MEMBER", "MODERATOR"} {
		t.Run(role, func(t *testing.T) {
			request := httptest.NewRequest("GET", "/api/v1/admin/readiness", nil)
			want := 401
			if role != "" {
				request = request.WithContext(sessionapi.WithPrincipal(request.Context(), authenticatesession.Principal{Role: role}))
				want = 403
			}
			response := httptest.NewRecorder()
			handler.ServeHTTP(response, request)
			if response.Code != want || response.Header().Get("Cache-Control") != "no-store" {
				t.Fatalf("status=%d headers=%v", response.Code, response.Header())
			}
		})
	}
}

func TestAdministratorReadinessSeparatesLivenessAndSafeDependencyResults(t *testing.T) {
	for _, failed := range []bool{false, true} {
		var privateError error
		want := 200
		if failed {
			privateError = errors.New("postgres://secret-host credential=private-secret")
			want = 503
		}
		service := New(databaseStub{privateError}, sfuStub{privateError}, storageStub{err: privateError, available: 5 << 30}, func() int64 { return 0 })
		request := httptest.NewRequest("GET", "/api/v1/admin/readiness", nil)
		request = request.WithContext(sessionapi.WithPrincipal(request.Context(), authenticatesession.Principal{Role: "ADMINISTRATOR"}))
		response := httptest.NewRecorder()
		Handler(service).ServeHTTP(response, request)
		if response.Code != want || response.Header().Get("Cache-Control") != "no-store" {
			t.Fatalf("status=%d headers=%v", response.Code, response.Header())
		}
		var result Result
		if err := json.Unmarshal(response.Body.Bytes(), &result); err != nil || (result.Status == "ready") == failed {
			t.Fatalf("result=%+v err=%v", result, err)
		}
		for _, forbidden := range []string{"secret-host", "private-secret", "postgres://", "credential="} {
			if strings.Contains(response.Body.String(), forbidden) {
				t.Fatal("private dependency error leaked")
			}
		}
		if failed && (result.Database.PendingRevocations != nil || result.Storage.AvailableBytes != nil) {
			t.Fatal("failed dependency manufactured a measurement")
		}
		live := httptest.NewRecorder()
		health.NewHandler().ServeHTTP(live, httptest.NewRequest("GET", "/api/v1/health", nil))
		if live.Code != 200 || live.Body.String() != "{\"status\":\"ok\"}\n" {
			t.Fatal("public liveness changed or acquired private dependency details")
		}
	}
}
