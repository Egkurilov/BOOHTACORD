package connectsession

import (
	"context"
	"github.com/coder/websocket"
	"github.com/coder/websocket/wsjson"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
	"voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	sessionpostgres "voice-platform/backend/internal/identity/authenticate_session/postgres"
	revoke "voice-platform/backend/internal/identity/revoke_own_sessions"
	revokepostgres "voice-platform/backend/internal/identity/revoke_own_sessions/postgres"
	sessionrealtime "voice-platform/backend/internal/identity/revoke_own_sessions/realtime"
	"voice-platform/backend/internal/identity/session"
	eventhub "voice-platform/backend/internal/realtime/event_hub"
	guildfixture "voice-platform/backend/internal/testsupport/guild_lifecycle"
)

func TestOwnSessionRevocationClosesOnlyOldSocketBeforePeriodicRevalidation(t *testing.T) {
	f := guildfixture.New(t)
	current, err := session.Issue()
	if err != nil {
		t.Fatal(err)
	}
	old, err := session.Issue()
	if err != nil {
		t.Fatal(err)
	}
	for _, issued := range []session.Issued{current, old} {
		if _, err = f.Pool.Exec(f.Context, `INSERT INTO sessions(token_digest,user_id) VALUES($1,$2)`, issued.Digest[:], f.Admin); err != nil {
			t.Fatal(err)
		}
	}
	auth := authenticatesession.New(sessionpostgres.New(sessionpostgres.NewPoolDatabase(f.Pool)))
	events := eventhub.New(32)
	server := httptest.NewServer(sessionapi.Require(auth)(NewHandlerWithEvents(auth, time.Hour, nil, nil, nil, events)))
	defer server.Close()
	open := func(token string) *websocket.Conn {
		t.Helper()
		headers := http.Header{"Cookie": {session.CookieName + "=" + token}, "Origin": {server.URL}}
		socket, _, err := websocket.Dial(f.Context, "ws"+strings.TrimPrefix(server.URL, "http"), &websocket.DialOptions{HTTPHeader: headers})
		if err != nil {
			t.Fatal("session socket failed")
		}
		t.Cleanup(func() { socket.CloseNow() })
		var event Event
		if err = wsjson.Read(f.Context, socket, &event); err != nil || event.Kind != "connection.ready" {
			t.Fatal("socket not ready")
		}
		return socket
	}
	initiator, revoked := open(current.Token), open(old.Token)
	store := sessionrealtime.Store{Inner: revokepostgres.New(f.Pool), Events: events}
	if _, err = store.Revoke(f.Context, revoke.Input{AccountID: f.Admin, Current: current.Digest, Others: true}); err != nil {
		t.Fatal(err)
	}
	ctx, cancel := context.WithTimeout(f.Context, 3*time.Second)
	defer cancel()
	var event Event
	for {
		err = wsjson.Read(ctx, revoked, &event)
		if err != nil {
			break
		}
		if event.Kind == "session.state_changed" {
			t.Fatal("revoked socket received authenticated hint")
		}
	}
	if websocket.CloseStatus(err) != websocket.StatusPolicyViolation {
		t.Fatal("old socket was not invalidated promptly")
	}
	for {
		if err = wsjson.Read(ctx, initiator, &event); err != nil {
			t.Fatal("initiator socket closed")
		}
		if event.Kind == "session.state_changed" {
			break
		}
	}
	if _, err = auth.Authenticate(ctx, current.Token); err != nil {
		t.Fatal("initiator cookie revoked")
	}
	if _, err = auth.Authenticate(ctx, old.Token); err == nil {
		t.Fatal("old cookie still valid")
	}
}
