package senddirectmessageapi

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	senddirectmessage "voice-platform/backend/internal/chat/send_direct_message"
	"voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
)

func TestHandlerSendsForCurrentParticipantWithoutRoleBypass(t *testing.T) {
	var input senddirectmessage.Input
	handler := NewHandler(senderFunc(func(_ context.Context, candidate senddirectmessage.Input) (senddirectmessage.Result, error) {
		input = candidate
		return senddirectmessage.Result{ID: "44444444-4444-4444-8444-444444444444", DirectMessageID: candidate.DirectMessageID, AuthorID: candidate.ActorID, ClientMessageID: candidate.ClientMessageID, Body: candidate.Body, ReplyToID: candidate.ReplyToID, Revision: 1, CreatedAt: time.Unix(1, 0)}, nil
	}))
	request := httptest.NewRequest(http.MethodPost, "/api/v1/direct-messages/22222222-2222-4222-8222-222222222222/messages", strings.NewReader(`{"client_message_id":"33333333-3333-4333-8333-333333333333","reply_to_id":"55555555-5555-4555-8555-555555555555","body":"Привет"}`))
	request.SetPathValue("directMessageID", "22222222-2222-4222-8222-222222222222")
	request = request.WithContext(sessionapi.WithPrincipal(request.Context(), authenticatesession.Principal{AccountID: "11111111-1111-4111-8111-111111111111", Role: "ADMINISTRATOR"}))
	recorder := httptest.NewRecorder()

	handler.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusCreated || input.ActorID != "11111111-1111-4111-8111-111111111111" || input.DirectMessageID == "" || input.ReplyToID != "55555555-5555-4555-8555-555555555555" || !strings.Contains(recorder.Body.String(), `"reply_to_id":"55555555-5555-4555-8555-555555555555"`) || !strings.Contains(recorder.Body.String(), `"revision":1`) {
		t.Fatalf("status=%d input=%#v body=%q", recorder.Code, input, recorder.Body.String())
	}
}

func TestHandlerForwardsAttachmentIDs(t *testing.T) {
	var input senddirectmessage.Input
	handler := NewHandler(senderFunc(func(_ context.Context, candidate senddirectmessage.Input) (senddirectmessage.Result, error) {
		input = candidate
		return senddirectmessage.Result{ID: "44444444-4444-4444-8444-444444444444"}, nil
	}))
	request := httptest.NewRequest(http.MethodPost, "/api/v1/direct-messages/pair/messages", strings.NewReader(`{"client_message_id":"33333333-3333-4333-8333-333333333333","body":"Привет","attachment_ids":["aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"]}`))
	request.SetPathValue("directMessageID", "22222222-2222-4222-8222-222222222222")
	request = request.WithContext(sessionapi.WithPrincipal(request.Context(), authenticatesession.Principal{AccountID: "11111111-1111-4111-8111-111111111111"}))
	response := httptest.NewRecorder()
	handler.ServeHTTP(response, request)
	if response.Code != 201 || len(input.AttachmentIDs) != 1 || input.AttachmentIDs[0] != "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa" {
		t.Fatalf("status=%d input=%#v", response.Code, input)
	}
}

type senderFunc func(context.Context, senddirectmessage.Input) (senddirectmessage.Result, error)

func (function senderFunc) Send(context context.Context, input senddirectmessage.Input) (senddirectmessage.Result, error) {
	return function(context, input)
}
