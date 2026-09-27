package createtextmessageapi

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	createtextmessage "voice-platform/backend/internal/chat/create_text_message"
	"voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
)

func TestHandlerUsesCurrentPrincipalAndPathChannel(t *testing.T) {
	var input createtextmessage.Input
	handler := NewHandler(creatorFunc(func(_ context.Context, value createtextmessage.Input) (createtextmessage.Result, error) {
		input = value
		return createtextmessage.Result{ID: "message-1", ChannelID: value.ChannelID, AuthorID: value.ActorID, ClientMessageID: value.ClientMessageID, Body: value.Body, ReplyToID: value.ReplyToID, Revision: 1, CreatedAt: time.Time{}}, nil
	}))
	request := httptest.NewRequest(http.MethodPost, "/api/v1/channels/text-1/messages", strings.NewReader(`{"client_message_id":"client-1","body":"Привет","reply_to_id":"message-0","attachment_ids":["attachment-1"]}`))
	request.SetPathValue("channelID", "text-1")
	request = request.WithContext(sessionapi.WithPrincipal(request.Context(), authenticatesession.Principal{AccountID: "user-1"}))
	recorder := httptest.NewRecorder()
	handler.ServeHTTP(recorder, request)
	if recorder.Code != http.StatusCreated || input.ActorID != "user-1" || input.ChannelID != "text-1" || len(input.AttachmentIDs) != 1 || input.AttachmentIDs[0] != "attachment-1" || !strings.Contains(recorder.Body.String(), `"client_message_id":"client-1"`) || !strings.Contains(recorder.Body.String(), `"revision":1`) {
		t.Fatalf("status = %d, input = %#v, body = %q", recorder.Code, input, recorder.Body.String())
	}
}

func TestHandlerAttachmentOnlyRequiresFile(t *testing.T) {
	const actor = "a1b4cc4a-2f12-4c7e-8f18-9d6dba5c6610"
	const channel = "b1b4cc4a-2f12-4c7e-8f18-9d6dba5c6610"
	creator := createtextmessage.New(messageStoreFunc(func(_ context.Context, request createtextmessage.Request) (createtextmessage.Result, error) {
		return createtextmessage.Result{ID: request.ID, ChannelID: request.ChannelID, AuthorID: request.ActorID, ClientMessageID: request.ClientMessageID, Body: request.Body}, nil
	}))
	for _, item := range []struct {
		name, payload string
		want          int
	}{
		{"with file", `{"client_message_id":"c1b4cc4a-2f12-4c7e-8f18-9d6dba5c6610","body":"","attachment_ids":["e1b4cc4a-2f12-4c7e-8f18-9d6dba5c6610"]}`, http.StatusCreated},
		{"without file", `{"client_message_id":"c1b4cc4a-2f12-4c7e-8f18-9d6dba5c6610","body":"","attachment_ids":[]}`, http.StatusBadRequest},
	} {
		t.Run(item.name, func(t *testing.T) {
			request := httptest.NewRequest(http.MethodPost, "/api/v1/channels/"+channel+"/messages", strings.NewReader(item.payload))
			request.SetPathValue("channelID", channel)
			request = request.WithContext(sessionapi.WithPrincipal(request.Context(), authenticatesession.Principal{AccountID: actor}))
			recorder := httptest.NewRecorder()
			NewHandler(creator).ServeHTTP(recorder, request)
			if recorder.Code != item.want {
				t.Fatalf("status = %d, want %d, body = %q", recorder.Code, item.want, recorder.Body.String())
			}
		})
	}
}

type messageStoreFunc func(context.Context, createtextmessage.Request) (createtextmessage.Result, error)

func (function messageStoreFunc) Create(ctx context.Context, request createtextmessage.Request) (createtextmessage.Result, error) {
	return function(ctx, request)
}

type creatorFunc func(context.Context, createtextmessage.Input) (createtextmessage.Result, error)

func (function creatorFunc) Create(context context.Context, input createtextmessage.Input) (createtextmessage.Result, error) {
	return function(context, input)
}
