package connectsession

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/coder/websocket"
	"github.com/coder/websocket/wsjson"
	"voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	eventhub "voice-platform/backend/internal/realtime/event_hub"
)

type replayJournal struct {
	events      []eventhub.Event
	replayError error
	allowed     map[string]bool
	replayed    func()
}

func (*replayJournal) Append(context.Context, eventhub.Event, []string, string) error { return nil }
func (journal *replayJournal) Replay(_ context.Context, _, _, _ string, _ int) ([]eventhub.Event, error) {
	if journal.replayed != nil {
		journal.replayed()
	}
	return journal.events, journal.replayError
}
func (journal *replayJournal) Authorize(_ context.Context, _ string, event eventhub.Event) (bool, error) {
	if journal.allowed == nil {
		return true, nil
	}
	return journal.allowed[event.EventID], nil
}

func openReplaySocket(t *testing.T, hub *eventhub.Hub, authentication sessionapi.Authenticator) (*websocket.Conn, func()) {
	t.Helper()
	handler := NewHandlerWithEvents(authentication, time.Hour, time.Now, nil, nil, hub)
	server := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		handler.ServeHTTP(writer, request.WithContext(sessionapi.WithPrincipal(request.Context(), authenticatesession.Principal{AccountID: "44444444-4444-4444-8444-444444444444"})))
	}))
	connection, _, err := websocket.Dial(context.Background(), "ws"+strings.TrimPrefix(server.URL, "http")+"?after=11111111-1111-4111-8111-111111111111", &websocket.DialOptions{HTTPHeader: http.Header{"Origin": {server.URL}, "Cookie": {"vp_session=opaque"}}})
	if err != nil {
		server.Close()
		t.Fatal(err)
	}
	return connection, func() { connection.CloseNow(); server.Close() }
}

func TestReplaySkipsRevokedDMAndDoesNotRevealItsID(t *testing.T) {
	dm := eventhub.Event{EventID: "22222222-2222-4222-8222-222222222222", Kind: "direct_message.message_created", Payload: map[string]any{"direct_message_id": "secret-pair"}}
	channel := eventhub.Event{EventID: "33333333-3333-4333-8333-333333333333", Kind: "channel.updated", Payload: map[string]any{"revision": 2}}
	journal := &replayJournal{events: []eventhub.Event{dm, channel}, allowed: map[string]bool{channel.EventID: true}}
	hub := eventhub.New(8)
	hub.SetJournal(journal)
	auth := authenticatorFunc(func(context.Context, string) (authenticatesession.Principal, error) {
		return authenticatesession.Principal{AccountID: "44444444-4444-4444-8444-444444444444"}, nil
	})
	connection, closeSocket := openReplaySocket(t, hub, auth)
	defer closeSocket()
	for index := 0; index < 4; index++ {
		var event Event
		ctx, cancel := context.WithTimeout(context.Background(), time.Second)
		err := wsjson.Read(ctx, connection, &event)
		cancel()
		if err != nil {
			t.Fatal(err)
		}
		if event.Kind == dm.Kind || strings.Contains(event.EventID, dm.EventID) {
			t.Fatalf("revoked DM leaked: %#v", event)
		}
		if index == 1 && event.Kind != "channel.updated" {
			t.Fatalf("expected authorized replay: %#v", event)
		}
	}
}

func TestReplayUnknownCursorRequiresResync(t *testing.T) {
	hub := eventhub.New(8)
	hub.SetJournal(&replayJournal{replayError: errors.New("unknown cursor")})
	auth := authenticatorFunc(func(context.Context, string) (authenticatesession.Principal, error) {
		return authenticatesession.Principal{AccountID: "44444444-4444-4444-8444-444444444444"}, nil
	})
	connection, closeSocket := openReplaySocket(t, hub, auth)
	defer closeSocket()
	var event Event
	if err := wsjson.Read(context.Background(), connection, &event); err != nil || event.Kind != "connection.resync_required" {
		t.Fatalf("event=%#v error=%v", event, err)
	}
}

func TestReplayRejectsRevokedSessionBeforePrivateHint(t *testing.T) {
	dm := eventhub.Event{EventID: "22222222-2222-4222-8222-222222222222", Kind: "direct_message.message_created", Payload: map[string]any{"direct_message_id": "secret-pair"}}
	hub := eventhub.New(8)
	hub.SetJournal(&replayJournal{events: []eventhub.Event{dm}})
	auth := authenticatorFunc(func(context.Context, string) (authenticatesession.Principal, error) {
		return authenticatesession.Principal{}, authenticatesession.ErrUnauthenticated
	})
	connection, closeSocket := openReplaySocket(t, hub, auth)
	defer closeSocket()
	var event Event
	err := wsjson.Read(context.Background(), connection, &event)
	if websocket.CloseStatus(err) != websocket.StatusPolicyViolation {
		t.Fatalf("revoked session got event=%#v error=%v", event, err)
	}
}
