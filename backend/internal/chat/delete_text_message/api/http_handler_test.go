package deletetextmessageapi

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"

	deletetextmessage "voice-platform/backend/internal/chat/delete_text_message"
	"voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
)

func TestHandlerUsesVerifiedPrincipalRoleAndPath(t *testing.T) {
	var input deletetextmessage.Input
	handler := NewHandler(deleterFunc(func(_ context.Context, value deletetextmessage.Input) (deletetextmessage.Result, error) {
		input = value
		return deletetextmessage.Result{}, nil
	}))
	request := httptest.NewRequest(http.MethodDelete, "/api/v1/channels/channel-1/messages/message-1", nil)
	request.SetPathValue("channelID", "channel-1")
	request.SetPathValue("messageID", "message-1")
	request = request.WithContext(sessionapi.WithPrincipal(request.Context(), authenticatesession.Principal{AccountID: "admin-1", Role: "ADMINISTRATOR"}))
	recorder := httptest.NewRecorder()
	handler.ServeHTTP(recorder, request)
	if recorder.Code != http.StatusNoContent || input.ActorID != "admin-1" || input.ActorRole != "ADMINISTRATOR" || input.ChannelID != "channel-1" || input.MessageID != "message-1" {
		t.Fatalf("status = %d, input = %#v", recorder.Code, input)
	}
}

type deleterFunc func(context.Context, deletetextmessage.Input) (deletetextmessage.Result, error)

func (function deleterFunc) Delete(context context.Context, input deletetextmessage.Input) (deletetextmessage.Result, error) {
	return function(context, input)
}
