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
	"voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	"voice-platform/backend/internal/realtime/admit_connection"
)

func TestHandlerSendsReadyEventForVerifiedSession(t *testing.T) {
	handler := NewHandler(nil, 0, func() time.Time { return time.Date(2026, 9, 17, 12, 0, 0, 0, time.UTC) }, func() string { return "a1b4cc4a-2f12-4c7e-8f18-9d6dba5c6610" }, nil)
	server := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		handler.ServeHTTP(writer, request.WithContext(sessionapi.WithPrincipal(request.Context(), authenticatesession.Principal{AccountID: "user-1"})))
	}))
	defer server.Close()
	connection, _, err := websocket.Dial(context.Background(), "ws"+strings.TrimPrefix(server.URL, "http"), &websocket.DialOptions{HTTPHeader: http.Header{"Origin": {server.URL}}})
	if err != nil {
		t.Fatalf("Dial() error = %v", err)
	}
	defer connection.CloseNow()
	var event Event
	if err := wsjson.Read(context.Background(), connection, &event); err != nil {
		t.Fatalf("Read() error = %v", err)
	}
	if event.EventID != "a1b4cc4a-2f12-4c7e-8f18-9d6dba5c6610" || event.Kind != "connection.ready" || !event.OccurredAt.Equal(time.Date(2026, 9, 17, 12, 0, 0, 0, time.UTC)) {
		t.Fatalf("event = %#v", event)
	}
}

func TestHandlerRequestsResyncInsteadOfUnverifiedReplay(t *testing.T) {
	nextID := 0
	handler := NewHandler(nil, 0, time.Now, func() string { nextID++; return "a1b4cc4a-2f12-4c7e-8f18-9d6dba5c6610" }, nil)
	server := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		handler.ServeHTTP(writer, request.WithContext(sessionapi.WithPrincipal(request.Context(), authenticatesession.Principal{AccountID: "user-1"})))
	}))
	defer server.Close()
	connection, _, err := websocket.Dial(context.Background(), "ws"+strings.TrimPrefix(server.URL, "http")+"?after=old-event", &websocket.DialOptions{HTTPHeader: http.Header{"Origin": {server.URL}}})
	if err != nil {
		t.Fatalf("Dial() error = %v", err)
	}
	defer connection.CloseNow()
	var event Event
	if err := wsjson.Read(context.Background(), connection, &event); err != nil || event.Kind != "connection.resync_required" || event.Payload["reason"] != "replay_unavailable" {
		t.Fatalf("event = %#v, error = %v", event, err)
	}
}

func TestHandlerClosesSocketWhenSessionIsRevoked(t *testing.T) {
	const token = "opaque-token"
	handler := NewHandler(authenticatorFunc(func(_ context.Context, got string) (authenticatesession.Principal, error) {
		if got != token {
			t.Fatalf("token = %q", got)
		}
		return authenticatesession.Principal{}, authenticatesession.ErrUnauthenticated
	}), time.Millisecond, time.Now, nil, nil)
	server := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		handler.ServeHTTP(writer, request.WithContext(sessionapi.WithPrincipal(request.Context(), authenticatesession.Principal{AccountID: "user-1"})))
	}))
	defer server.Close()
	connection, _, err := websocket.Dial(context.Background(), "ws"+strings.TrimPrefix(server.URL, "http"), &websocket.DialOptions{HTTPHeader: http.Header{
		"Cookie": {"vp_session=" + token}, "Origin": {server.URL},
	}})
	if err != nil {
		t.Fatalf("Dial() error = %v", err)
	}
	defer connection.CloseNow()
	var event Event
	if err := wsjson.Read(context.Background(), connection, &event); err != nil || event.Kind != "connection.ready" {
		t.Fatalf("ready event = %#v, error = %v", event, err)
	}
	readContext, cancel := context.WithTimeout(context.Background(), time.Second)
	defer cancel()
	err = wsjson.Read(readContext, connection, &event)
	if websocket.CloseStatus(err) != websocket.StatusPolicyViolation {
		t.Fatalf("CloseStatus() = %v, error = %v", websocket.CloseStatus(err), err)
	}
}

func TestHandlerRejectsOverQuotaBeforeUpgradeAndReleasesOnClose(t *testing.T) {
	quota, err := admitconnection.New(admitconnection.Config{GlobalLimit: 1, AccountLimit: 1, SessionLimit: 1})
	if err != nil {
		t.Fatal(err)
	}
	handler := NewHandlerWithAdmission(nil, 0, time.Now, nil, nil, nil, quota)
	server := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		handler.ServeHTTP(writer, request.WithContext(sessionapi.WithPrincipal(request.Context(), authenticatesession.Principal{AccountID: "member"})))
	}))
	defer server.Close()
	endpoint := "ws" + strings.TrimPrefix(server.URL, "http")
	first, _, err := websocket.Dial(context.Background(), endpoint, &websocket.DialOptions{HTTPHeader: http.Header{"Origin": {server.URL}}})
	if err != nil {
		t.Fatal(err)
	}
	_, response, err := websocket.Dial(context.Background(), endpoint, &websocket.DialOptions{HTTPHeader: http.Header{"Origin": {server.URL}}})
	if err == nil || response == nil || response.StatusCode != http.StatusTooManyRequests || response.Header.Get("Retry-After") != "1" {
		t.Fatalf("over-quota response = %#v, error = %v", response, err)
	}
	first.CloseNow()
	waitForQuotaToDrain(t, quota)
	third, _, err := websocket.Dial(context.Background(), endpoint, &websocket.DialOptions{HTTPHeader: http.Header{"Origin": {server.URL}}})
	if err != nil {
		t.Fatalf("connection slot was not released: %v", err)
	}
	third.CloseNow()
}

type authenticatorFunc func(context.Context, string) (authenticatesession.Principal, error)

func (function authenticatorFunc) Authenticate(context context.Context, token string) (authenticatesession.Principal, error) {
	return function(context, token)
}
