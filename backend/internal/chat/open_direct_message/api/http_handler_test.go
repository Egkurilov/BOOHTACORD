package opendirectmessageapi

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	opendirectmessage "voice-platform/backend/internal/chat/open_direct_message"
	"voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
)

func TestHandlerOpensDirectMessageForCurrentAccountWithoutRoleBypass(t *testing.T) {
	var input opendirectmessage.Input
	handler := NewHandler(openerFunc(func(_ context.Context, candidate opendirectmessage.Input) (opendirectmessage.Result, error) {
		input = candidate
		return opendirectmessage.Result{ID: "33333333-3333-4333-8333-333333333333", ParticipantOneID: candidate.ActorID, ParticipantTwoID: candidate.ParticipantID, CreatedAt: time.Unix(1, 0)}, nil
	}))
	request := httptest.NewRequest(http.MethodPost, "/api/v1/direct-messages", strings.NewReader(`{"participant_id":"22222222-2222-4222-8222-222222222222"}`))
	request = request.WithContext(sessionapi.WithPrincipal(request.Context(), authenticatesession.Principal{AccountID: "11111111-1111-4111-8111-111111111111", Role: "ADMINISTRATOR"}))
	recorder := httptest.NewRecorder()

	handler.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusCreated || input != (opendirectmessage.Input{ActorID: "11111111-1111-4111-8111-111111111111", ParticipantID: "22222222-2222-4222-8222-222222222222"}) || !strings.Contains(recorder.Body.String(), `"id":"33333333-3333-4333-8333-333333333333"`) {
		t.Fatalf("status=%d input=%#v body=%q", recorder.Code, input, recorder.Body.String())
	}
}

type openerFunc func(context.Context, opendirectmessage.Input) (opendirectmessage.Result, error)
func (function openerFunc) Open(context context.Context, input opendirectmessage.Input) (opendirectmessage.Result, error) { return function(context, input) }
