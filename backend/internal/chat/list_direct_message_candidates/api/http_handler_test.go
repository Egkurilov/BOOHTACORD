package listdirectmessagecandidatesapi

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	listdirectmessagecandidates "voice-platform/backend/internal/chat/list_direct_message_candidates"
	"voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
)

const (
	candidateActor = "11111111-1111-4111-8111-111111111111"
	candidateA     = "22222222-2222-4222-8222-222222222222"
	candidateB     = "33333333-3333-4333-8333-333333333333"
)

func TestHandlerListsCandidatesForCurrentPrincipalWithBoundedCursor(t *testing.T) {
	var input listdirectmessagecandidates.Input
	handler := NewHandler(listerFunc(func(_ context.Context, value listdirectmessagecandidates.Input) (listdirectmessagecandidates.Result, error) {
		input = value
		return listdirectmessagecandidates.Result{Candidates: []listdirectmessagecandidates.Candidate{{ID: candidateB, DisplayName: "Борис"}}, NextAfter: candidateB}, nil
	}))
	request := httptest.NewRequest(http.MethodGet, "/api/v1/direct-message-candidates?after="+candidateA+"&limit=2", nil)
	request = request.WithContext(sessionapi.WithPrincipal(request.Context(), authenticatesession.Principal{AccountID: candidateActor, Role: "ADMINISTRATOR"}))
	recorder := httptest.NewRecorder()

	handler.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusOK || input != (listdirectmessagecandidates.Input{ActorID: candidateActor, After: candidateA, Limit: 2}) || !strings.Contains(recorder.Body.String(), `"display_name":"Борис"`) || !strings.Contains(recorder.Body.String(), `"next_after":"`+candidateB+`"`) {
		t.Fatalf("status=%d input=%#v body=%q", recorder.Code, input, recorder.Body.String())
	}
}

type listerFunc func(context.Context, listdirectmessagecandidates.Input) (listdirectmessagecandidates.Result, error)

func (function listerFunc) List(context context.Context, input listdirectmessagecandidates.Input) (listdirectmessagecandidates.Result, error) {
	return function(context, input)
}
