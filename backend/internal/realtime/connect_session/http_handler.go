package connectsession

import (
	"context"
	"net/http"
	"time"

	"github.com/coder/websocket"
	"github.com/coder/websocket/wsjson"
	"github.com/google/uuid"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	"voice-platform/backend/internal/identity/session"
)

type Event struct {
	EventID    string         `json:"event_id"`
	Kind       string         `json:"kind"`
	OccurredAt time.Time      `json:"occurred_at"`
	Payload    map[string]any `json:"payload"`
}

type Clock func() time.Time
type Identifier func() string

type ConnectionObserver interface {
	RealtimeConnectionOpened()
	ObserveRealtimeConnectionReady(time.Duration)
	RealtimeConnectionClosed()
}

const defaultSessionRevalidationInterval = 15 * time.Second

func NewHandler(authenticator sessionapi.Authenticator, revalidationInterval time.Duration, now Clock, newID Identifier, observer ConnectionObserver) http.Handler {
	if now == nil {
		now = time.Now
	}
	if newID == nil {
		newID = uuid.NewString
	}
	if revalidationInterval <= 0 {
		revalidationInterval = defaultSessionRevalidationInterval
	}
	return http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		if _, ok := sessionapi.PrincipalFrom(request.Context()); !ok {
			writer.WriteHeader(http.StatusInternalServerError)
			return
		}
		cookie, err := request.Cookie(session.CookieName)
		if authenticator != nil && err != nil {
			writer.WriteHeader(http.StatusInternalServerError)
			return
		}
		connection, err := websocket.Accept(writer, request, nil)
		if err != nil {
			return
		}
		acceptedAt := time.Now()
		if observer != nil {
			observer.RealtimeConnectionOpened()
			defer observer.RealtimeConnectionClosed()
		}
		defer connection.CloseNow()
		writeContext, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		if request.URL.Query().Has("after") {
			if !writeEvent(writeContext, connection, newID, now, "connection.resync_required", map[string]any{"reason": "replay_unavailable"}) {
				return
			}
		}
		if !writeEvent(writeContext, connection, newID, now, "connection.ready", map[string]any{}) {
			return
		}
		if observer != nil {
			observer.ObserveRealtimeConnectionReady(time.Since(acceptedAt))
		}
		waitForCloseOrSessionRevocation(connection, authenticator, cookie, revalidationInterval)
	})
}

func waitForCloseOrSessionRevocation(connection *websocket.Conn, authenticator sessionapi.Authenticator, cookie *http.Cookie, revalidationInterval time.Duration) {
	closed := connection.CloseRead(context.Background()).Done()
	if authenticator == nil {
		<-closed
		return
	}
	ticker := time.NewTicker(revalidationInterval)
	defer ticker.Stop()
	for {
		select {
		case <-closed:
			return
		case <-ticker.C:
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
