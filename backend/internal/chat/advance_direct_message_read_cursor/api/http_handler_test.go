package advancedirectmessagereadcursorapi

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	advancedirectmessagereadcursor "voice-platform/backend/internal/chat/advance_direct_message_read_cursor"
	"voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
)

func TestHandlerUsesPrincipalWithoutRoleBypass(t *testing.T) {
	var input advancedirectmessagereadcursor.Input
	handler := NewHandler(advancerFunc(func(_ context.Context, value advancedirectmessagereadcursor.Input) (advancedirectmessagereadcursor.Result, error) {
		input = value
		return advancedirectmessagereadcursor.Result{MessageID: value.MessageID}, nil
	}))
	request := httptest.NewRequest(http.MethodPut, "/api/v1/direct-messages/22222222-2222-4222-8222-222222222222/read-cursor", strings.NewReader(`{"message_id":"33333333-3333-4333-8333-333333333333"}`))
	request.SetPathValue("directMessageID", "22222222-2222-4222-8222-222222222222")
	request = request.WithContext(sessionapi.WithPrincipal(request.Context(), authenticatesession.Principal{AccountID: "11111111-1111-4111-8111-111111111111", Role: "ADMINISTRATOR"}))
	recorder := httptest.NewRecorder()

	handler.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusOK || input.ActorID != "11111111-1111-4111-8111-111111111111" || input.DirectMessageID == "" || input.MessageID == "" {
		t.Fatalf("status=%d input=%#v", recorder.Code, input)
	}
}

type advancerFunc func(context.Context, advancedirectmessagereadcursor.Input) (advancedirectmessagereadcursor.Result, error)

func (function advancerFunc) Advance(context context.Context, input advancedirectmessagereadcursor.Input) (advancedirectmessagereadcursor.Result, error) {
	return function(context, input)
}
