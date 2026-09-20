package listdirectmessagesapi

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	listdirectmessages "voice-platform/backend/internal/chat/list_direct_messages"
	"voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
)

func TestHandlerListsOnlyCurrentPrincipalsDirectMessagesWithoutRoleBypass(t *testing.T) {
	var input listdirectmessages.Input
	handler := NewHandler(listerFunc(func(_ context.Context, value listdirectmessages.Input) (listdirectmessages.Result, error) {
		input = value
		return listdirectmessages.Result{DirectMessages: []listdirectmessages.DirectMessage{{ID: "22222222-2222-4222-8222-222222222222", OtherParticipantID: "33333333-3333-4333-8333-333333333333", OtherParticipantDisplayName: "Собеседник", UnreadCount: 3}}}, nil
	}))
	request := httptest.NewRequest(http.MethodGet, "/api/v1/direct-messages", nil)
	request = request.WithContext(sessionapi.WithPrincipal(request.Context(), authenticatesession.Principal{AccountID: "11111111-1111-4111-8111-111111111111", Role: "ADMINISTRATOR"}))
	recorder := httptest.NewRecorder()

	handler.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusOK || input.ActorID != "11111111-1111-4111-8111-111111111111" || !strings.Contains(recorder.Body.String(), `"other_participant_display_name":"Собеседник"`) || !strings.Contains(recorder.Body.String(), `"unread_count":3`) {
		t.Fatalf("status=%d input=%#v body=%q", recorder.Code, input, recorder.Body.String())
	}
}

type listerFunc func(context.Context, listdirectmessages.Input) (listdirectmessages.Result, error)

func (function listerFunc) List(context context.Context, input listdirectmessages.Input) (listdirectmessages.Result, error) {
	return function(context, input)
}
