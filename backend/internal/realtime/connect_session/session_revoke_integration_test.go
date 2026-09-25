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
	"github.com/google/uuid"
	"voice-platform/backend/internal/identity/admin_account"
	adminpostgres "voice-platform/backend/internal/identity/admin_account/postgres"
	"voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	sessionpostgres "voice-platform/backend/internal/identity/authenticate_session/postgres"
	"voice-platform/backend/internal/identity/session"
)

func TestBlockRevokesLiveWebSocketWithRealSessionStore(t *testing.T) {
	pool := newConnectionFixture(t)
	ctx := context.Background()
	ownerID, memberID := uuid.NewString(), uuid.NewString()
	for _, user := range []struct{ id, login, role string }{
		{ownerID, "qa02owner", "ADMINISTRATOR"},
		{memberID, "qa02member", "MEMBER"},
	} {
		if _, err := pool.Exec(ctx, `INSERT INTO users (id,login,display_name,password_hash,role) VALUES ($1,$2,'QA user','test',$3)`, user.id, user.login, user.role); err != nil {
			t.Fatal(err)
		}
	}
	issued, err := session.Issue()
	if err != nil {
		t.Fatal(err)
	}
	if _, err := pool.Exec(ctx, `INSERT INTO sessions (token_digest,user_id) VALUES ($1,$2)`, issued.Digest[:], memberID); err != nil {
		t.Fatal(err)
	}
	auth := authenticatesession.New(sessionpostgres.New(sessionpostgres.NewPoolDatabase(pool)))
	handler := sessionapi.Require(auth)(NewHandler(auth, 10*time.Millisecond, time.Now, nil, nil))
	server := httptest.NewServer(handler)
	defer server.Close()
	url := "ws" + strings.TrimPrefix(server.URL, "http")
	headers := http.Header{"Cookie": {session.CookieName + "=" + issued.Token}, "Origin": {server.URL}}
	connection, _, err := websocket.Dial(ctx, url, &websocket.DialOptions{HTTPHeader: headers})
	if err != nil {
		t.Fatal(err)
	}
	defer connection.CloseNow()
	var event Event
	if err := wsjson.Read(ctx, connection, &event); err != nil || event.Kind != "connection.ready" {
		t.Fatalf("ready event = %#v, error = %v", event, err)
	}
	admin := adminaccount.New(adminpostgres.New(adminpostgres.NewPoolDatabase(pool)))
	if _, err := admin.Update(ctx, adminaccount.Input{ActorID: ownerID, AccountID: memberID, Role: adminaccount.RoleMember, Blocked: true}); err != nil {
		t.Fatal(err)
	}
	readContext, cancel := context.WithTimeout(ctx, 2*time.Second)
	defer cancel()
	err = wsjson.Read(readContext, connection, &event)
	if websocket.CloseStatus(err) != websocket.StatusPolicyViolation {
		t.Fatalf("socket close status = %v, error = %v", websocket.CloseStatus(err), err)
	}
	_, response, err := websocket.Dial(ctx, url, &websocket.DialOptions{HTTPHeader: headers})
	if err == nil || response == nil || response.StatusCode != http.StatusUnauthorized {
		t.Fatalf("revoked session reconnect response = %#v, error = %v", response, err)
	}
}
