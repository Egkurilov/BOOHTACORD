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
	event = Event{}
	if err := wsjson.Read(context.Background(), connection, &event); err != nil || event.Kind != "presence.snapshot" {
		t.Fatalf("presence snapshot = %#v, error = %v", event, err)
	}
	event = Event{}
	if err := wsjson.Read(context.Background(), connection, &event); err != nil || event.Kind != "presence.changed" || event.Payload["presence"] != "online" {
		t.Fatalf("presence changed = %#v, error = %v", event, err)
	}
	hub.Publish(eventhub.Event{EventID: "33333333-3333-4333-8333-333333333333", Kind: "message.created", OccurredAt: time.Now().UTC(), Payload: map[string]any{"channel_id": "11111111-1111-4111-8111-111111111111", "message_id": "22222222-2222-4222-8222-222222222222"}})
	event = Event{}
	if err := wsjson.Read(context.Background(), connection, &event); err != nil {
		t.Fatalf("message event read error = %v", err)
	}
	if event.Kind != "message.created" || len(event.Payload) != 2 || event.Payload["message_id"] != "22222222-2222-4222-8222-222222222222" {
		t.Fatalf("message event exposed unexpected data: %#v", event)
	}
}

func TestHandlerTracksAuthenticatedPresenceUntilConnectionCloses(t *testing.T) {
	hub := eventhub.New(2)
	handler := NewHandlerWithEvents(nil, time.Hour, time.Now, nil, nil, hub)
	server := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		handler.ServeHTTP(writer, request.WithContext(sessionapi.WithPrincipal(request.Context(), auth.Principal{AccountID: "user-1"})))
	}))
	defer server.Close()
	connection, _, err := websocket.Dial(context.Background(), "ws"+strings.TrimPrefix(server.URL, "http"), &websocket.DialOptions{HTTPHeader: http.Header{"Origin": {server.URL}}})
	if err != nil {
		t.Fatalf("Dial() error = %v", err)
	}
	var ready Event
	if err := wsjson.Read(context.Background(), connection, &ready); err != nil || ready.Kind != "connection.ready" || !hub.IsOnline("user-1") {
		t.Fatalf("ready=%#v err=%v online=%v", ready, err, hub.IsOnline("user-1"))
	}
	var snapshot Event
	if err := wsjson.Read(context.Background(), connection, &snapshot); err != nil || snapshot.Kind != "presence.snapshot" {
		t.Fatalf("snapshot=%#v err=%v", snapshot, err)
	}
	if online, ok := snapshot.Payload["online_user_ids"].([]interface{}); !ok || len(online) != 1 || online[0] != "user-1" {
		t.Fatalf("snapshot did not contain authenticated account: %#v", snapshot.Payload)
	}
	if err := connection.Close(websocket.StatusNormalClosure, "done"); err != nil {
		t.Fatalf("Close() error = %v", err)
	}
	deadline := time.Now().Add(time.Second)
	for hub.IsOnline("user-1") && time.Now().Before(deadline) {
		time.Sleep(time.Millisecond)
	}
	if hub.IsOnline("user-1") {
		t.Fatal("closed realtime session remained online")
	}
}
