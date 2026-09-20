package deletedirectmessageapi

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"

	deletedirectmessage "voice-platform/backend/internal/chat/delete_direct_message"
	"voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
)

func TestHandlerUsesPrincipalAndDirectMessagePathWithoutRoleBypass(t *testing.T) {
	var input deletedirectmessage.Input
	handler := NewHandler(deleterFunc(func(_ context.Context, value deletedirectmessage.Input) (deletedirectmessage.Result, error) {
		input = value
		return deletedirectmessage.Result{}, nil
	}))
	request := httptest.NewRequest(http.MethodDelete, "/api/v1/direct-messages/22222222-2222-4222-8222-222222222222/messages/33333333-3333-4333-8333-333333333333", nil)
	request.SetPathValue("directMessageID", "22222222-2222-4222-8222-222222222222")
	request.SetPathValue("messageID", "33333333-3333-4333-8333-333333333333")
	request = request.WithContext(sessionapi.WithPrincipal(request.Context(), authenticatesession.Principal{AccountID: "11111111-1111-4111-8111-111111111111", Role: "ADMINISTRATOR"}))
	recorder := httptest.NewRecorder()

	handler.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusNoContent || input.ActorID != "11111111-1111-4111-8111-111111111111" || input.DirectMessageID == "" || input.MessageID == "" {
		t.Fatalf("status=%d input=%#v", recorder.Code, input)
	}
}

type deleterFunc func(context.Context, deletedirectmessage.Input) (deletedirectmessage.Result, error)

func (function deleterFunc) Delete(context context.Context, input deletedirectmessage.Input) (deletedirectmessage.Result, error) {
	return function(context, input)
}
