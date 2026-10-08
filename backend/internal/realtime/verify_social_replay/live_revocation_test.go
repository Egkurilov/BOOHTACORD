package verifysocialreplay

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
	connect "voice-platform/backend/internal/realtime/connect_session"
	hub "voice-platform/backend/internal/realtime/event_hub"
)

func TestActualWebSocketRevokedSessionGetsNoPrivateReactionHint(t *testing.T) {
	h := hub.New(8)
	var revoked atomic.Bool
	principal := auth.Principal{AccountID: "44444444-4444-4444-8444-444444444444"}
	authenticator := authenticatorFunc(func(context.Context, string) (auth.Principal, error) {
		if revoked.Load() {
			return auth.Principal{}, auth.ErrUnauthenticated
		}
		return principal, nil
	})
	handler := connect.NewHandlerWithEvents(authenticator, time.Hour, time.Now, nil, nil, h)
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		handler.ServeHTTP(w, r.WithContext(sessionapi.WithPrincipal(r.Context(), principal)))
	}))
	defer server.Close()
	c, _, err := websocket.Dial(t.Context(), "ws"+strings.TrimPrefix(server.URL, "http")+"?capabilities=message_social_v1", &websocket.DialOptions{HTTPHeader: http.Header{"Origin": {server.URL}, "Cookie": {"vp_session=opaque"}}})
	if err != nil {
		t.Fatal(err)
	}
	defer c.CloseNow()
	for index := 0; index < 2; index++ {
		var event hub.Event
		if err := wsjson.Read(t.Context(), c, &event); err != nil {
			t.Fatal(err)
		}
	}
	revoked.Store(true)
	h.PublishToAccounts([]string{principal.AccountID}, hub.Event{Kind: "direct_message.reactions_updated", Payload: map[string]any{"direct_message_id": "pair", "message_id": "message"}})
	ctx, cancel := context.WithTimeout(t.Context(), time.Second)
	defer cancel()
	for index := 0; index < 5; index++ {
		var event hub.Event
		err = wsjson.Read(ctx, c, &event)
		if websocket.CloseStatus(err) == websocket.StatusPolicyViolation {
			return
		}
		if err != nil || event.Kind == "direct_message.reactions_updated" {
			t.Fatalf("revoked session received hint kind=%q error=%v", event.Kind, err)
		}
	}
	t.Fatal("revoked session was not disconnected")
}
