package connectsession

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/coder/websocket"
	"github.com/coder/websocket/wsjson"
	auth "voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	eventhub "voice-platform/backend/internal/realtime/event_hub"
)

func TestHandlerStreamsPublishedMessageHintWithoutContent(t *testing.T) {
	hub := eventhub.New(2)
	handler := NewHandlerWithEvents(nil, time.Hour, time.Now, nil, nil, hub)
	server := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		principal := auth.Principal{AccountID: "user-1"}
		handler.ServeHTTP(writer, request.WithContext(sessionapi.WithPrincipal(request.Context(), principal)))
	}))
	defer server.Close()
	connection, _, err := websocket.Dial(context.Background(), "ws"+strings.TrimPrefix(server.URL, "http"), &websocket.DialOptions{HTTPHeader: http.Header{"Origin": {server.URL}}})
	if err != nil {
		t.Fatalf("Dial() error = %v", err)
	}
	defer connection.CloseNow()
	var event Event
	if err := wsjson.Read(context.Background(), connection, &event); err != nil || event.Kind != "connection.ready" {
		t.Fatalf("ready event = %#v, error = %v", event, err)
	}
	hub.Publish(eventhub.Event{EventID: "33333333-3333-4333-8333-333333333333", Kind: "message.created", OccurredAt: time.Now().UTC(), Payload: map[string]any{"channel_id": "11111111-1111-4111-8111-111111111111", "message_id": "22222222-2222-4222-8222-222222222222"}})
	if err := wsjson.Read(context.Background(), connection, &event); err != nil {
		t.Fatalf("message event read error = %v", err)
	}
	if event.Kind != "message.created" || len(event.Payload) != 2 || event.Payload["message_id"] != "22222222-2222-4222-8222-222222222222" {
		t.Fatalf("message event exposed unexpected data: %#v", event)
	}
}
