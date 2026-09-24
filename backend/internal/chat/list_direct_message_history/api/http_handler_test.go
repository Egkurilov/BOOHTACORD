package listdirectmessagehistoryapi

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	listdirectmessagehistory "voice-platform/backend/internal/chat/list_direct_message_history"
	"voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
)

func TestHandlerReadsPageForCurrentParticipantWithoutRoleBypass(t *testing.T) {
	var input listdirectmessagehistory.Input
	handler := NewHandler(listerFunc(func(_ context.Context, value listdirectmessagehistory.Input) (listdirectmessagehistory.Result, error) {
		input = value
		return listdirectmessagehistory.Result{Messages: []listdirectmessagehistory.Message{{ID: "44444444-4444-4444-8444-444444444444", DirectMessageID: "22222222-2222-4222-8222-222222222222", ReplyToID: "55555555-5555-4555-8555-555555555555", ReplyPreview: &listdirectmessagehistory.ReplyPreview{ID: "55555555-5555-4555-8555-555555555555", AuthorID: "66666666-6666-4666-8666-666666666666", Body: "", Deleted: true}, Deleted: true, Revision: 1}}, NextCursor: "44444444-4444-4444-8444-444444444444"}, nil
	}))
	request := httptest.NewRequest(http.MethodGet, "/api/v1/direct-messages/22222222-2222-4222-8222-222222222222/messages?limit=10&before=33333333-3333-4333-8333-333333333333", nil)
	request.SetPathValue("directMessageID", "22222222-2222-4222-8222-222222222222")
	request = request.WithContext(sessionapi.WithPrincipal(request.Context(), authenticatesession.Principal{AccountID: "11111111-1111-4111-8111-111111111111", Role: "ADMINISTRATOR"}))
	recorder := httptest.NewRecorder()

	handler.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusOK || input.ActorID != "11111111-1111-4111-8111-111111111111" || input.Limit != 10 || input.Before == "" || !strings.Contains(recorder.Body.String(), `"direct_message_id":"22222222-2222-4222-8222-222222222222"`) || !strings.Contains(recorder.Body.String(), `"reply_to_id":"55555555-5555-4555-8555-555555555555"`) || !strings.Contains(recorder.Body.String(), `"reply_preview":{"id":"55555555-5555-4555-8555-555555555555"`) || !strings.Contains(recorder.Body.String(), `"deleted":true`) || !strings.Contains(recorder.Body.String(), `"attachments":[]`) {
		t.Fatalf("status=%d input=%#v body=%q", recorder.Code, input, recorder.Body.String())
	}
}

func TestHandlerIncludesOnlyAttachmentMetadata(t *testing.T) {
	handler := NewHandler(listerFunc(func(_ context.Context, _ listdirectmessagehistory.Input) (listdirectmessagehistory.Result, error) {
		return listdirectmessagehistory.Result{Messages: []listdirectmessagehistory.Message{{Attachments: []listdirectmessagehistory.Attachment{{ID: "file", OriginalName: "safe.txt", ByteSize: 3}}}}}, nil
	}))
	request := httptest.NewRequest(http.MethodGet, "/api/v1/direct-messages/pair/messages", nil)
	request = request.WithContext(sessionapi.WithPrincipal(request.Context(), authenticatesession.Principal{AccountID: "11111111-1111-4111-8111-111111111111"}))
	response := httptest.NewRecorder()
	handler.ServeHTTP(response, request)
	if response.Code != 200 || !strings.Contains(response.Body.String(), `"attachments":[{"id":"file","original_name":"safe.txt","byte_size":3}]`) || strings.Contains(response.Body.String(), "storage_key") {
		t.Fatalf("status=%d body=%q", response.Code, response.Body.String())
	}
}

type listerFunc func(context.Context, listdirectmessagehistory.Input) (listdirectmessagehistory.Result, error)

func (function listerFunc) List(context context.Context, input listdirectmessagehistory.Input) (listdirectmessagehistory.Result, error) {
	return function(context, input)
}
