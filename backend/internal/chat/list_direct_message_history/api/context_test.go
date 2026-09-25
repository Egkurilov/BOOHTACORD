package listdirectmessagehistoryapi

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"

	listdirectmessagehistory "voice-platform/backend/internal/chat/list_direct_message_history"
	"voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
)

func TestHandlerPassesAddressedContextAnchorForPrincipal(t *testing.T) {
	var input listdirectmessagehistory.Input
	handler := NewHandler(listerFunc(func(_ context.Context, value listdirectmessagehistory.Input) (listdirectmessagehistory.Result, error) {
		input = value
		return listdirectmessagehistory.Result{}, nil
	}))
	request := httptest.NewRequest(http.MethodGet, "/api/v1/direct-messages/pair/messages?at=message-1&limit=20", nil)
	request.SetPathValue("directMessageID", "pair")
	request = request.WithContext(sessionapi.WithPrincipal(request.Context(), authenticatesession.Principal{AccountID: "participant"}))
	recorder := httptest.NewRecorder()
	handler.ServeHTTP(recorder, request)
	if recorder.Code != http.StatusOK || input.ActorID != "participant" || input.At != "message-1" || input.Limit != 20 {
		t.Fatalf("status = %d, input = %#v", recorder.Code, input)
	}
}
