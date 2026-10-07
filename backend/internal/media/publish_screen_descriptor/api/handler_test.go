package publishscreendescriptorapi

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	authenticatesession "voice-platform/backend/internal/identity/authenticate_session"
	"voice-platform/backend/internal/identity/session"
	publishdescriptor "voice-platform/backend/internal/media/publish_screen_descriptor"
)

const leaseID = "11111111-1111-4111-8111-111111111111"
const expectedOrigin = "https://voice.example.test"

type authStub struct{}

func (authStub) Authenticate(_ context.Context, token string) (authenticatesession.Principal, error) {
	if token != "session" {
		return authenticatesession.Principal{}, authenticatesession.ErrUnauthenticated
	}
	return authenticatesession.Principal{AccountID: "viewer", SessionDigest: [32]byte{7}}, nil
}

type operationStub struct {
	calls         int
	principal     publishdescriptor.Principal
	lease, origin string
	descriptor    publishdescriptor.Descriptor
	err           error
}

func (stub *operationStub) Apply(_ context.Context, principal publishdescriptor.Principal, lease, origin string, descriptor publishdescriptor.Descriptor) error {
	stub.calls++
	stub.principal, stub.lease, stub.origin, stub.descriptor = principal, lease, origin, descriptor
	return stub.err
}

func TestUpdateRequiresSessionAndExactOrigin(t *testing.T) {
	for _, origin := range []string{"", "https://attacker.example"} {
		operations, mux := &operationStub{}, (*http.ServeMux)(nil)
		mux = newMux(operations)
		response := httptest.NewRecorder()
		mux.ServeHTTP(response, request("", origin))
		if response.Code != http.StatusForbidden || operations.calls != 0 {
			t.Fatalf("origin %q: status=%d calls=%d", origin, response.Code, operations.calls)
		}
	}
	operations, mux := &operationStub{}, (*http.ServeMux)(nil)
	mux = newMux(operations)
	unauthenticated := request("", expectedOrigin)
	unauthenticated.Header.Del("Cookie")
	response := httptest.NewRecorder()
	mux.ServeHTTP(response, unauthenticated)
	if response.Code != http.StatusUnauthorized || operations.calls != 0 {
		t.Fatalf("unauthenticated status=%d calls=%d", response.Code, operations.calls)
	}
}

func TestUpdatePassesBoundOriginAndAuthenticatedPrincipal(t *testing.T) {
	operations := &operationStub{}
	mux := newMux(operations)
	request := request("", expectedOrigin)
	response := httptest.NewRecorder()
	mux.ServeHTTP(response, request)
	if response.Code != http.StatusNoContent || operations.calls != 1 {
		t.Fatalf("status=%d calls=%d body=%s", response.Code, operations.calls, response.Body.String())
	}
	if operations.lease != leaseID || operations.origin != expectedOrigin || operations.principal.AccountID != "viewer" || operations.principal.SessionDigest[0] != 7 {
		t.Fatalf("bound input = %#v", operations)
	}
	if operations.descriptor.Scope.AccountID != "attacker-account" {
		t.Fatal("handler unexpectedly rewrote repository-owned descriptor scope")
	}
	if response.Header().Get("X-Screen-Profile-Operation-Revision") != "3" {
		t.Fatal("operation revision header missing")
	}
}

func newMux(operations *operationStub) *http.ServeMux {
	mux := http.NewServeMux()
	RegisterRoutes(mux, authStub{}, operations, expectedOrigin)
	return mux
}

func request(_ string, origin string) *http.Request {
	request := httptest.NewRequest(http.MethodPut, "/api/v1/voice/leases/"+leaseID+"/screen-profile/v1", strings.NewReader(validJSON()))
	request.AddCookie(&http.Cookie{Name: session.CookieName, Value: "session"})
	request.Header.Set("Origin", origin)
	request.Header.Set("Content-Type", "application/json")
	return request
}

func validJSON() string {
	value := map[string]any{"schema_version": 1, "scope": map[string]any{"origin_id": expectedOrigin, "account_id": "attacker-account", "room_id": "voice:attacker-room", "media_session_id": "session-1", "publication_generation": 2, "operation_revision": 3},
		"mode": "text", "publisher_state": "sharing", "viewer_state": "idle", "requested_profile_id": "P1080_30",
		"effective_profile": map[string]any{"capture": map[string]any{"max_width": 1920, "max_height": 1080, "max_fps": 30}, "encoding": map[string]any{"codec": nil, "layers": []any{map[string]any{"rid": nil, "width": 1920, "height": 1080, "max_fps": 30, "max_bitrate_bps": 2000000, "scale_down_by": 1, "active": true}}}},
		"layer_topology":    "single-layer", "profile_revision": 1, "capabilities": map[string]any{"live_update": true, "republish_without_recapture": true, "simulcast": false}, "reason_codes": []string{"user-request"}}
	encoded, _ := json.Marshal(value)
	return string(encoded)
}
