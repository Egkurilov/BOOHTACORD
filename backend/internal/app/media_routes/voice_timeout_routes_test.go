package mediaroutes

import (
	"net/http"
	"net/http/httptest"
	"testing"
	auth "voice-platform/backend/internal/identity/authenticate_session"
)

func TestTimeoutRoutesRequireSession(t *testing.T) {
	mux := http.NewServeMux()
	ConfigureAdminVoiceRoutes(mux, nil, auth.Service{})
	for _, route := range []struct{ method, path string }{
		{"PUT", "/api/v1/admin/accounts/target/voice-timeout"},
		{"DELETE", "/api/v1/admin/accounts/target/voice-timeout"},
		{"GET", "/api/v1/accounts/target/voice-timeout"},
	} {
		w := httptest.NewRecorder()
		mux.ServeHTTP(w, httptest.NewRequest(route.method, route.path, nil))
		if w.Code != http.StatusUnauthorized {
			t.Fatalf("%s %s status=%d", route.method, route.path, w.Code)
		}
	}
}
