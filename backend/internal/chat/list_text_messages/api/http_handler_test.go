package listtextmessagesapi

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	listtextmessages "voice-platform/backend/internal/chat/list_text_messages"
)

const attachmentID = "c1b4cc4a-2f12-4c7e-8f18-9d6dba5c6610"

func TestHandlerReadsCursorPage(t *testing.T) {
	var input listtextmessages.Input
	handler := NewHandler(listerFunc(func(_ context.Context, value listtextmessages.Input) (listtextmessages.Result, error) {
		input = value
		return listtextmessages.Result{Messages: []listtextmessages.Message{{ID: "message-1", Revision: 1, Attachments: []listtextmessages.Attachment{{ID: attachmentID, OriginalName: "notes.svg", SizeBytes: 10}}}}, NextCursor: "message-1"}, nil
	}))
	request := httptest.NewRequest(http.MethodGet, "/api/v1/channels/b1b4cc4a-2f12-4c7e-8f18-9d6dba5c6610/messages?limit=10&before=c1b4cc4a-2f12-4c7e-8f18-9d6dba5c6610", nil)
	request.SetPathValue("channelID", "b1b4cc4a-2f12-4c7e-8f18-9d6dba5c6610")
	recorder := httptest.NewRecorder()
	handler.ServeHTTP(recorder, request)
	if recorder.Code != http.StatusOK || input.Limit != 10 || input.Before == "" || !strings.Contains(recorder.Body.String(), `"attachments":[{"id":"`+attachmentID) || !strings.Contains(recorder.Body.String(), `"original_name":"notes.svg"`) || !strings.Contains(recorder.Body.String(), `"byte_size":10`) || strings.Contains(recorder.Body.String(), "storage_key") || !strings.Contains(recorder.Body.String(), `"revision":1`) {
		t.Fatalf("status = %d, input = %#v, body = %q", recorder.Code, input, recorder.Body.String())
	}
}

type listerFunc func(context.Context, listtextmessages.Input) (listtextmessages.Result, error)

func (function listerFunc) List(context context.Context, input listtextmessages.Input) (listtextmessages.Result, error) {
	return function(context, input)
}
