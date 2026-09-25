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
	reader := &fakeReader{result: listauditevents.Result{Events: []listauditevents.Event{{ID: "9", ActorID: "actor-1", ActorDisplayName: "Администратор", ActorLogin: "admin_fixture", TargetID: "target-1", TargetDisplayName: "Альфа", TargetLogin: "alpha_fixture", EventType: "PASSWORD_CHANGED", CreatedAt: time.Unix(1, 0)}}}}
	handler := sessionapi.RequireAdministrator(NewHandler(reader))
	request := httptest.NewRequest(http.MethodGet, "/api/v1/admin/audit?limit=20", nil)
	request = request.WithContext(sessionapi.WithPrincipal(request.Context(), authenticatesession.Principal{AccountID: "admin", Role: "ADMINISTRATOR"}))
	recorder := httptest.NewRecorder()
	handler.ServeHTTP(recorder, request)
	if recorder.Code != http.StatusOK || strings.Contains(recorder.Body.String(), "metadata") || strings.Contains(recorder.Body.String(), "message body") || !strings.Contains(recorder.Body.String(), `"actor_display_name":"Администратор"`) || !strings.Contains(recorder.Body.String(), `"target_login":"alpha_fixture"`) || reader.input.Limit != 20 {
		t.Fatalf("status=%d body=%q input=%#v", recorder.Code, recorder.Body.String(), reader.input)
	}
	unauthorized := httptest.NewRecorder()
	NewHandler(reader).ServeHTTP(unauthorized, httptest.NewRequest(http.MethodGet, "/api/v1/admin/audit", nil))
	if unauthorized.Code != http.StatusUnauthorized {
		t.Fatalf("unauthorized status=%d", unauthorized.Code)
	}
	memberRequest := httptest.NewRequest(http.MethodGet, "/api/v1/admin/audit", nil)
	memberRequest = memberRequest.WithContext(sessionapi.WithPrincipal(memberRequest.Context(), authenticatesession.Principal{AccountID: "member", Role: "MEMBER"}))
	member := httptest.NewRecorder()
	handler.ServeHTTP(member, memberRequest)
	if member.Code != http.StatusForbidden || reader.calls != 1 || strings.Contains(member.Body.String(), "admin_fixture") {
		t.Fatalf("member status=%d calls=%d body=%q", member.Code, reader.calls, member.Body.String())
	}
}

type fakeReader struct {
	input  listauditevents.Input
	result listauditevents.Result
	calls  int
}

func (reader *fakeReader) List(_ context.Context, input listauditevents.Input) (listauditevents.Result, error) {
	reader.input = input
	reader.calls++
	return reader.result, nil
}
