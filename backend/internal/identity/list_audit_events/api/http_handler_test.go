package listauditeventsapi

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	"voice-platform/backend/internal/identity/list_audit_events"
)

func TestHandlerRequiresSessionAndReturnsOnlySafeAuditFields(t *testing.T) {
	reader := &fakeReader{result: listauditevents.Result{Events: []listauditevents.Event{{ID: "9", ActorID: "actor-1", TargetID: "target-1", EventType: "PASSWORD_CHANGED", CreatedAt: time.Unix(1, 0)}}}}
	handler := NewHandler(reader)
	request := httptest.NewRequest(http.MethodGet, "/api/v1/admin/audit?limit=20", nil)
	request = request.WithContext(sessionapi.WithPrincipal(request.Context(), authenticatesession.Principal{AccountID: "admin", Role: "ADMINISTRATOR"}))
	recorder := httptest.NewRecorder()
	handler.ServeHTTP(recorder, request)
	if recorder.Code != http.StatusOK || strings.Contains(recorder.Body.String(), "metadata") || strings.Contains(recorder.Body.String(), "message body") || reader.input.Limit != 20 {
		t.Fatalf("status=%d body=%q input=%#v", recorder.Code, recorder.Body.String(), reader.input)
	}
	unauthorized := httptest.NewRecorder()
	handler.ServeHTTP(unauthorized, httptest.NewRequest(http.MethodGet, "/api/v1/admin/audit", nil))
	if unauthorized.Code != http.StatusUnauthorized {
		t.Fatalf("unauthorized status=%d", unauthorized.Code)
	}
}

type fakeReader struct {
	input  listauditevents.Input
	result listauditevents.Result
}

func (reader *fakeReader) List(_ context.Context, input listauditevents.Input) (listauditevents.Result, error) {
	reader.input = input
	return reader.result, nil
}
