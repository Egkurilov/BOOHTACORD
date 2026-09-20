package editdirectmessageapi

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	editdirectmessage "voice-platform/backend/internal/chat/edit_direct_message"
	"voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
)

func TestHandlerUsesPrincipalPathAndExpectedRevisionWithoutRoleBypass(t *testing.T) {
	var input editdirectmessage.Input
	handler := NewHandler(editorFunc(func(_ context.Context, value editdirectmessage.Input) (editdirectmessage.Result, error) {
		input = value
		return editdirectmessage.Result{ID: value.MessageID, DirectMessageID: value.DirectMessageID, AuthorID: value.ActorID, Body: value.Body, Revision: 2, EditedAt: time.Unix(2, 0)}, nil
	}))
	request := httptest.NewRequest(http.MethodPatch, "/api/v1/direct-messages/22222222-2222-4222-8222-222222222222/messages/33333333-3333-4333-8333-333333333333", strings.NewReader(`{"body":"исправлено","expected_revision":1}`))
	request.SetPathValue("directMessageID", "22222222-2222-4222-8222-222222222222")
	request.SetPathValue("messageID", "33333333-3333-4333-8333-333333333333")
	request = request.WithContext(sessionapi.WithPrincipal(request.Context(), authenticatesession.Principal{AccountID: "11111111-1111-4111-8111-111111111111", Role: "ADMINISTRATOR"}))
	recorder := httptest.NewRecorder()

	handler.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusOK || input.ActorID != "11111111-1111-4111-8111-111111111111" || input.DirectMessageID == "" || input.MessageID == "" || input.ExpectedRevision != 1 || !strings.Contains(recorder.Body.String(), `"revision":2`) {
		t.Fatalf("status=%d input=%#v body=%q", recorder.Code, input, recorder.Body.String())
	}
}

type editorFunc func(context.Context, editdirectmessage.Input) (editdirectmessage.Result, error)

func (function editorFunc) Edit(context context.Context, input editdirectmessage.Input) (editdirectmessage.Result, error) {
	return function(context, input)
}
