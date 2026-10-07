package publishscreendescriptorapi

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"voice-platform/backend/internal/identity/session"
)

func TestUpdateBoundsDescriptorBody(t *testing.T) {
	operations := &operationStub{}
	mux := newMux(operations)
	request := httptest.NewRequest(http.MethodPut, "/api/v1/voice/leases/"+leaseID+"/screen-profile/v1", strings.NewReader(strings.Repeat("x", maxDescriptorBytes+1)))
	request.AddCookie(&http.Cookie{Name: session.CookieName, Value: "session"})
	request.Header.Set("Origin", expectedOrigin)
	request.Header.Set("Content-Type", "application/json")
	response := httptest.NewRecorder()
	mux.ServeHTTP(response, request)
	if response.Code != http.StatusRequestEntityTooLarge || operations.calls != 0 {
		t.Fatalf("oversize body status=%d calls=%d", response.Code, operations.calls)
	}
}
