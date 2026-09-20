package edittextmessageapi

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	edittextmessage "voice-platform/backend/internal/chat/edit_text_message"
	"voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
)

func TestHandlerUsesPrincipalPathAndExpectedRevision(t *testing.T) {
	var input edittextmessage.Input
	handler := NewHandler(editorFunc(func(_ context.Context, value edittextmessage.Input) (edittextmessage.Result, error) {
		input = value
		return edittextmessage.Result{ID: value.MessageID, ChannelID: value.ChannelID, AuthorID: value.ActorID, Body: value.Body, Revision: 2}, nil
	}))
	request := httptest.NewRequest(http.MethodPatch, "/api/v1/channels/channel-1/messages/message-1", strings.NewReader(`{"body":"исправлено","expected_revision":1}`))
	request.SetPathValue("channelID", "channel-1")
	request.SetPathValue("messageID", "message-1")
	request = request.WithContext(sessionapi.WithPrincipal(request.Context(), authenticatesession.Principal{AccountID: "user-1"}))
	recorder := httptest.NewRecorder()
	handler.ServeHTTP(recorder, request)
	if recorder.Code != http.StatusOK || input.ActorID != "user-1" || input.ChannelID != "channel-1" || input.MessageID != "message-1" || input.ExpectedRevision != 1 || !strings.Contains(recorder.Body.String(), `"revision":2`) {
		t.Fatalf("status = %d, input = %#v, body = %q", recorder.Code, input, recorder.Body.String())
	}
}

type editorFunc func(context.Context, edittextmessage.Input) (edittextmessage.Result, error)

func (function editorFunc) Edit(context context.Context, input edittextmessage.Input) (edittextmessage.Result, error) {
	return function(context, input)
}
