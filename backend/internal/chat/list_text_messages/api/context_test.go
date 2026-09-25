package listtextmessagesapi

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"

	listtextmessages "voice-platform/backend/internal/chat/list_text_messages"
)

func TestHandlerPassesAddressedContextAnchor(t *testing.T) {
	var input listtextmessages.Input
	handler := NewHandler(listerFunc(func(_ context.Context, value listtextmessages.Input) (listtextmessages.Result, error) {
		input = value
		return listtextmessages.Result{}, nil
	}))
	request := httptest.NewRequest(http.MethodGet, "/api/v1/channels/channel-1/messages?at=message-1&limit=20", nil)
	request.SetPathValue("channelID", "channel-1")
	recorder := httptest.NewRecorder()
	handler.ServeHTTP(recorder, request)
	if recorder.Code != http.StatusOK || input.At != "message-1" || input.Limit != 20 {
		t.Fatalf("status = %d, input = %#v", recorder.Code, input)
	}
}
