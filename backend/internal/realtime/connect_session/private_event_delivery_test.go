package connectsession

import (
	"context"
	"github.com/coder/websocket"
	"github.com/coder/websocket/wsjson"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync/atomic"
	"testing"
	"time"
	auth "voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	eventhub "voice-platform/backend/internal/realtime/event_hub"
)

func TestRevokedSessionDoesNotReceiveQueuedDirectMessageEvent(t *testing.T) {
	hub := eventhub.New(4)
	var revoked atomic.Bool
	handler := NewHandlerWithEvents(authenticatorFunc(func(_ context.Context, token string) (auth.Principal, error) {
		if token != "opaque-token" || revoked.Load() {
			return auth.Principal{}, auth.ErrUnauthenticated
		}
		return auth.Principal{AccountID: "member"}, nil
	}), time.Hour, time.Now, nil, nil, hub)
	server := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		handler.ServeHTTP(writer, request.WithContext(sessionapi.WithPrincipal(request.Context(), auth.Principal{AccountID: "member"})))
	}))
	defer server.Close()
	connection, _, err := websocket.Dial(context.Background(), "ws"+strings.TrimPrefix(server.URL, "http"), &websocket.DialOptions{HTTPHeader: http.Header{
		"Cookie": {"vp_session=opaque-token"}, "Origin": {server.URL},
	}})
	if err != nil {
		t.Fatal(err)
	}
	defer connection.CloseNow()
	for _, kind := range []string{"connection.ready", "presence.snapshot", "presence.changed"} {
		var event Event
		if err := wsjson.Read(context.Background(), connection, &event); err != nil || event.Kind != kind {
			t.Fatalf("initial event kind=%q got=%#v err=%v", kind, event, err)
		}
	}
	revoked.Store(true)
	hub.PublishToAccounts([]string{"member"}, eventhub.Event{EventID: "private", Kind: "direct_message.message_created", Payload: map[string]any{"direct_message_id": "secret-pair", "message_id": "secret-message"}})
	readContext, cancel := context.WithTimeout(context.Background(), time.Second)
	defer cancel()
	var event Event
	err = wsjson.Read(readContext, connection, &event)
	if websocket.CloseStatus(err) != websocket.StatusPolicyViolation {
		t.Fatalf("revoked session saw event=%#v, close status=%v, err=%v", event, websocket.CloseStatus(err), err)
	}
}

func TestPrivateDirectMessageEventRechecksAuthenticatedAccount(t *testing.T) {
	hub := eventhub.New(4)
	handler := NewHandlerWithEvents(authenticatorFunc(func(_ context.Context, _ string) (auth.Principal, error) {
		return auth.Principal{AccountID: "other-account"}, nil
	}), time.Hour, time.Now, nil, nil, hub)
	server := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		handler.ServeHTTP(writer, request.WithContext(sessionapi.WithPrincipal(request.Context(), auth.Principal{AccountID: "member"})))
	}))
	defer server.Close()
	connection, _, err := websocket.Dial(context.Background(), "ws"+strings.TrimPrefix(server.URL, "http"), &websocket.DialOptions{HTTPHeader: http.Header{
		"Cookie": {"vp_session=opaque-token"}, "Origin": {server.URL},
	}})
	if err != nil {
		t.Fatal(err)
	}
	defer connection.CloseNow()
	for range 3 {
		var initial Event
		if err := wsjson.Read(context.Background(), connection, &initial); err != nil {
			t.Fatal(err)
		}
	}
	hub.PublishToAccounts([]string{"member"}, eventhub.Event{EventID: "private", Kind: "direct_message.message_created"})
	readContext, cancel := context.WithTimeout(context.Background(), time.Second)
	defer cancel()
	var event Event
	err = wsjson.Read(readContext, connection, &event)
	if websocket.CloseStatus(err) != websocket.StatusPolicyViolation {
		t.Fatalf("account mismatch saw event=%#v err=%v", event, err)
	}
}
