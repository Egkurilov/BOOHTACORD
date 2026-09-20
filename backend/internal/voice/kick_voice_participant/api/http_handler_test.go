package kickvoiceparticipantapi

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	kickvoiceparticipant "voice-platform/backend/internal/voice/kick_voice_participant"
)

func TestHandlerKicksTargetFromAdministrator(t *testing.T) {
	var captured kickvoiceparticipant.Input
	handler := NewHandler(kickerFunc(func(_ context.Context, input kickvoiceparticipant.Input) (kickvoiceparticipant.Result, error) {
		captured = input
		return kickvoiceparticipant.Result{RevokedLeases: 1}, nil
	}))
	request := httptest.NewRequest(http.MethodPost, "/api/v1/admin/accounts/user-1/voice-kick", nil)
	request.SetPathValue("accountID", "user-1")
	request = request.WithContext(sessionapi.WithPrincipal(request.Context(), authenticatesession.Principal{AccountID: "admin-1", Role: "ADMINISTRATOR"}))
	recorder := httptest.NewRecorder()
	handler.ServeHTTP(recorder, request)
	if recorder.Code != http.StatusOK || captured != (kickvoiceparticipant.Input{ActorID: "admin-1", TargetID: "user-1"}) || !strings.Contains(recorder.Body.String(), `"revoked_leases":1`) {
		t.Fatalf("status = %d, input = %#v, body = %q", recorder.Code, captured, recorder.Body.String())
	}
}

type kickerFunc func(context.Context, kickvoiceparticipant.Input) (kickvoiceparticipant.Result, error)

func (function kickerFunc) Kick(context context.Context, input kickvoiceparticipant.Input) (kickvoiceparticipant.Result, error) {
	return function(context, input)
}
