package connectsession

import (
	"context"
	"net/http"
	"time"

	"github.com/coder/websocket"
	"github.com/coder/websocket/wsjson"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	eventhub "voice-platform/backend/internal/realtime/event_hub"
)

func streamEvents(connection *websocket.Conn, authenticator sessionapi.Authenticator, cookie *http.Cookie, interval time.Duration, subscription *eventhub.Subscription, hub *eventhub.Hub, newID Identifier, now Clock) {
	closed := connection.CloseRead(context.Background()).Done()
	var events <-chan eventhub.Event
	var overflowed <-chan struct{}
	if subscription != nil {
		events, overflowed = subscription.Events(), subscription.Overflowed()
	}
	var ticker *time.Ticker
	var revalidate <-chan time.Time
	if authenticator != nil {
		ticker = time.NewTicker(interval)
		defer ticker.Stop()
		revalidate = ticker.C
	}
	for {
		select {
		case <-closed:
			return
		case event := <-events:
			writeContext, cancel := context.WithTimeout(context.Background(), 5*time.Second)
			err := wsjson.Write(writeContext, connection, event)
			cancel()
			if err != nil {
				return
			}
		case <-overflowed:
			writeContext, cancel := context.WithTimeout(context.Background(), 5*time.Second)
			ok := writeEvent(writeContext, connection, newID, now, "connection.resync_required", map[string]any{"reason": "event_overflow"})
			if ok && hub != nil {
				ok = writeEvent(writeContext, connection, newID, now, "presence.snapshot", map[string]any{"online_user_ids": hub.OnlineAccounts()})
			}
			cancel()
			if !ok {
				return
			}
			subscription.AcknowledgeOverflow()
		case <-revalidate:
			context, cancel := context.WithTimeout(context.Background(), 5*time.Second)
			_, err := authenticator.Authenticate(context, cookie.Value)
			cancel()
			if err != nil {
				_ = connection.Close(websocket.StatusPolicyViolation, "session is no longer valid")
				return
			}
		}
	}
}

func writeEvent(context context.Context, connection *websocket.Conn, newID Identifier, now Clock, kind string, payload map[string]any) bool {
	return wsjson.Write(context, connection, Event{EventID: newID(), Kind: kind, OccurredAt: now().UTC(), Payload: payload}) == nil
}
