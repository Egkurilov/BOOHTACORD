package verifysocialreplay

import (
	"context"
	"github.com/coder/websocket"
	"github.com/coder/websocket/wsjson"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
	auth "voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	connect "voice-platform/backend/internal/realtime/connect_session"
	hub "voice-platform/backend/internal/realtime/event_hub"
)

func TestActualWebSocketSocialReplayRequiresNegotiatedCapability(t *testing.T) {
	for _, capability := range []string{"", "message_social_v1"} {
		t.Run(capability, func(t *testing.T) {
			h := hub.New(8)
			social := hub.Event{EventID: "22222222-2222-4222-8222-222222222222", Kind: "message.reactions_updated", Payload: map[string]any{"channel_id": "channel", "message_id": "message"}}
			last := hub.Event{EventID: "33333333-3333-4333-8333-333333333333", Kind: "channel.updated", Payload: map[string]any{"revision": 1}}
			h.SetJournal(&replayJournal{events: []hub.Event{social, last}})
			principal := auth.Principal{AccountID: "44444444-4444-4444-8444-444444444444"}
			handler := connect.NewHandlerWithEvents(authenticatorFunc(func(context.Context, string) (auth.Principal, error) { return principal, nil }), time.Hour, time.Now, nil, nil, h)
			server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				handler.ServeHTTP(w, r.WithContext(sessionapi.WithPrincipal(r.Context(), principal)))
			}))
			defer server.Close()
			target := "ws" + strings.TrimPrefix(server.URL, "http") + "?after=11111111-1111-4111-8111-111111111111&capabilities=" + capability
			c, _, err := websocket.Dial(t.Context(), target, &websocket.DialOptions{HTTPHeader: http.Header{"Origin": {server.URL}, "Cookie": {"vp_session=opaque"}}})
			if err != nil {
				t.Fatal(err)
			}
			defer c.CloseNow()
			found := false
			for index := 0; index < 4; index++ {
				var event hub.Event
				ctx, cancel := context.WithTimeout(t.Context(), time.Second)
				err := wsjson.Read(ctx, c, &event)
				cancel()
				if err != nil {
					t.Fatal(err)
				}
				if event.Kind == social.Kind {
					found = true
				}
				if event.Kind == last.Kind {
					break
				}
			}
			if found != (capability != "") {
				t.Fatalf("social replay delivered=%v for capability=%q", found, capability)
			}
		})
	}
}
