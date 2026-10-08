package watchconnectedparticipants

import (
	"github.com/google/uuid"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	requestid "voice-platform/backend/internal/security/request_id"
)

func TestInitialDependencyFailureCorrelationIsServerGenerated(t *testing.T) {
	handler := requestid.Middleware(NewHandler(errorLister{}, NewNotifier(), nil))
	request := testSessionRequest(httptest.NewRequest(http.MethodGet, "/", nil))
	request.Header.Set("X-Request-ID", "private-account-id-client-forged")
	response := httptest.NewRecorder()
	handler.ServeHTTP(response, request)
	id := response.Header().Get("X-Request-ID")
	if response.Code != 503 || uuid.Validate(id) != nil || strings.Contains(response.Body.String(), "account-123") || strings.Contains(id, "private") {
		t.Fatalf("status=%d id=%q body=%s", response.Code, id, response.Body.String())
	}
}
