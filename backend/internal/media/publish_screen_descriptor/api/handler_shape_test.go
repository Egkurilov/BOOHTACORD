package publishscreendescriptorapi

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"voice-platform/backend/internal/identity/session"
)

func TestUpdateRejectsMalformedOrUnknownBodyFields(t *testing.T) {
	for _, body := range []string{
		"{}",
		strings.Replace(validJSON(), `"mode":"text"`, `"mode":"text","admin":true`, 1),
		strings.Replace(validJSON(), `"live_update":true,`, "", 1),
	} {
		operations := &operationStub{}
		mux := newMux(operations)
		request := httptest.NewRequest(http.MethodPut, "/api/v1/voice/leases/"+leaseID+"/screen-profile/v1", strings.NewReader(body))
		request.AddCookie(&http.Cookie{Name: session.CookieName, Value: "session"})
		request.Header.Set("Origin", expectedOrigin)
		request.Header.Set("Content-Type", "application/json")
		response := httptest.NewRecorder()
		mux.ServeHTTP(response, request)
		if response.Code != http.StatusBadRequest || operations.calls != 0 {
			t.Fatalf("body accepted: status=%d calls=%d", response.Code, operations.calls)
		}
	}
}
