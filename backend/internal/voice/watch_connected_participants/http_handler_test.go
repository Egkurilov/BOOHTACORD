package watchconnectedparticipants

import (
	"bufio"
	"context"
	"errors"
	"fmt"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync/atomic"
	"testing"
	"time"

	auth "voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	"voice-platform/backend/internal/identity/session"
	roster "voice-platform/backend/internal/voice/list_connected_participants"
)

type rosterStub struct{ actor string }

func (stub *rosterStub) List(_ context.Context, actor string) (roster.Result, error) {
	stub.actor = actor
	return roster.Result{Channels: []roster.ChannelRoster{{ChannelID: "room", Participants: []roster.Participant{}}}}, nil
}

type deadlineRosterStub struct {
	deadlineAt  time.Time
	hasDeadline bool
	cancel      context.CancelFunc
}

func (stub *deadlineRosterStub) List(ctx context.Context, _ string) (roster.Result, error) {
	stub.deadlineAt, stub.hasDeadline = ctx.Deadline()
	if stub.cancel != nil {
		stub.cancel()
	}
	return roster.Result{Channels: []roster.ChannelRoster{}}, nil
}

type notifyingRosterStub struct {
	notifier *Notifier
	calls    int
}

type changingRosterStub struct {
	calls atomic.Int32
	actor atomic.Value
}

func (stub *changingRosterStub) List(_ context.Context, actor string) (roster.Result, error) {
	stub.actor.Store(actor)
	if stub.calls.Add(1) == 1 {
		return roster.Result{Channels: []roster.ChannelRoster{{ChannelID: "before"}}}, nil
	}
	return roster.Result{Channels: []roster.ChannelRoster{{ChannelID: "after"}}}, nil
}

type sessionAuthenticatorFunc func(context.Context, string) (auth.Principal, error)

func (function sessionAuthenticatorFunc) Authenticate(ctx context.Context, token string) (auth.Principal, error) {
	return function(ctx, token)
}

func testSessionRequest(request *http.Request) *http.Request {
	request = request.WithContext(sessionapi.WithPrincipal(request.Context(), auth.Principal{
		AccountID: "viewer", SessionDigest: [32]byte{0: 1},
	}))
	request.AddCookie(&http.Cookie{Name: session.CookieName, Value: "active-session"})
	return request
}

func (stub *notifyingRosterStub) List(_ context.Context, _ string) (roster.Result, error) {
	stub.calls++
	if stub.calls == 1 {
		// Model a participant change while the initial roster is being loaded.
		stub.notifier.Notify()
	}
	return roster.Result{Channels: []roster.ChannelRoster{{ChannelID: fmt.Sprintf("snapshot-%d", stub.calls)}}}, nil
}

func TestStreamSendsAuthorizedSnapshotAndUpdatesOnNotification(t *testing.T) {
	notifier, lister := NewNotifier(), &changingRosterStub{}
	server := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		NewHandler(lister, notifier, sessionAuthenticatorFunc(func(context.Context, string) (auth.Principal, error) {
			return auth.Principal{AccountID: "viewer", SessionDigest: [32]byte{0: 1}}, nil
		})).ServeHTTP(writer, testSessionRequest(request))
	}))
	defer server.Close()
	client := &http.Client{Timeout: 3 * time.Second}
	response, err := client.Get(server.URL)
	if err != nil {
		t.Fatal(err)
	}
	defer response.Body.Close()
	reader := bufio.NewReader(response.Body)
	first, err := reader.ReadString('\n')
	if err != nil || !strings.Contains(first, `"channel_id":"before"`) || lister.actor.Load() != "viewer" {
		t.Fatalf("first=%s err=%v actor=%v", first, err, lister.actor.Load())
	}
	_, _ = reader.ReadString('\n') // SSE frame separator
	notifier.Notify()
	second, err := reader.ReadString('\n')
	if err != nil || !strings.Contains(second, `"channel_id":"after"`) {
		t.Fatalf("second=%s err=%v", second, err)
	}
}

func TestStreamReconcilesRosterChangesWithoutNotification(t *testing.T) {
	notifier, lister := NewNotifier(), &changingRosterStub{}
	handler := newHandler(lister, notifier, sessionAuthenticatorFunc(func(context.Context, string) (auth.Principal, error) {
		return auth.Principal{AccountID: "viewer", SessionDigest: [32]byte{0: 1}}, nil
	}), time.Hour, time.Hour, 10*time.Millisecond)
	server := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		handler.ServeHTTP(writer, testSessionRequest(request))
	}))
	defer server.Close()

	response, err := (&http.Client{Timeout: time.Second}).Get(server.URL)
	if err != nil {
		t.Fatal(err)
	}
	defer response.Body.Close()
	reader := bufio.NewReader(response.Body)
	if line, err := reader.ReadString('\n'); err != nil || !strings.Contains(line, `"channel_id":"before"`) {
		t.Fatalf("initial event = %q, err=%v", line, err)
	}
	_, _ = reader.ReadString('\n')
	if line, err := reader.ReadString('\n'); err != nil || !strings.Contains(line, `"channel_id":"after"`) {
		t.Fatalf("reconciled event = %q, err=%v", line, err)
	}
}

func TestStreamDoesNotMissChangeDuringInitialSnapshot(t *testing.T) {
	notifier := NewNotifier()
	lister := &notifyingRosterStub{notifier: notifier}
	server := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		NewHandler(lister, notifier, sessionAuthenticatorFunc(func(context.Context, string) (auth.Principal, error) {
			return auth.Principal{AccountID: "viewer", SessionDigest: [32]byte{0: 1}}, nil
		})).ServeHTTP(writer, testSessionRequest(request))
	}))
	defer server.Close()
	client := &http.Client{Timeout: 3 * time.Second}
	response, err := client.Get(server.URL)
	if err != nil {
		t.Fatal(err)
	}
	defer response.Body.Close()
	reader := bufio.NewReader(response.Body)
	first, err := reader.ReadString('\n')
	if err != nil || !strings.Contains(first, `"channel_id":"snapshot-1"`) {
		t.Fatalf("first=%s err=%v", first, err)
	}
	_, _ = reader.ReadString('\n') // SSE frame separator
	second, err := reader.ReadString('\n')
	if err != nil || !strings.Contains(second, `"channel_id":"snapshot-2"`) {
		t.Fatalf("second=%s err=%v calls=%d", second, err, lister.calls)
	}
}

func TestInitialSnapshotHasBoundedDeadline(t *testing.T) {
	notifier := NewNotifier()
	requestContext, cancel := context.WithCancel(context.Background())
	lister := &deadlineRosterStub{cancel: cancel}
	request := httptest.NewRequest(http.MethodGet, "/", nil)
	request = testSessionRequest(request)
	request = request.WithContext(sessionapi.WithPrincipal(requestContext, auth.Principal{AccountID: "viewer"}))
	NewHandler(lister, notifier, sessionAuthenticatorFunc(func(context.Context, string) (auth.Principal, error) {
		return auth.Principal{}, nil
	})).ServeHTTP(httptest.NewRecorder(), request)

	if !lister.hasDeadline {
		t.Fatal("initial roster snapshot did not receive a bounded context")
	}
	remaining := time.Until(lister.deadlineAt)
	if remaining <= 0 || remaining > 5*time.Second {
		t.Fatalf("initial snapshot deadline remaining = %s, want <= 5s", remaining)
	}
}

func TestStreamReauthenticatesWithoutClosingActiveSSEConnection(t *testing.T) {
	notifier := NewNotifier()
	lister := &changingRosterStub{}
	var authentications atomic.Int32
	authenticator := sessionAuthenticatorFunc(func(_ context.Context, token string) (auth.Principal, error) {
		if token != "active-session" {
			return auth.Principal{}, auth.ErrUnauthenticated
		}
		authentications.Add(1)
		return auth.Principal{AccountID: "viewer", SessionDigest: [32]byte{0: 1}}, nil
	})
	handler := newHandler(lister, notifier, authenticator, 100*time.Millisecond, time.Hour, time.Hour)
	server := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		handler.ServeHTTP(writer, testSessionRequest(request))
	}))
	defer server.Close()

	response, err := (&http.Client{Timeout: 15 * time.Second}).Get(server.URL)
	if err != nil {
		t.Fatal(err)
	}
	defer response.Body.Close()
	reader := bufio.NewReader(response.Body)
	if line, err := reader.ReadString('\n'); err != nil || !strings.Contains(line, `"channel_id":"before"`) {
		t.Fatalf("initial event = %q, err=%v", line, err)
	}
	_, _ = reader.ReadString('\n')
	time.Sleep(10*time.Second + 100*time.Millisecond)
	if authentications.Load() < 2 {
		t.Fatal("session was not reauthenticated while SSE remained open")
	}
	notifier.Notify()
	if line, err := reader.ReadString('\n'); err != nil || !strings.Contains(line, `"channel_id":"after"`) {
		t.Fatalf("updated event after session recheck = %q, err=%v", line, err)
	}
}

func TestStreamEmitsSessionExpiredEventAndClosesWhenSessionIsRevoked(t *testing.T) {
	notifier := NewNotifier()
	var authentications atomic.Int32
	authenticator := sessionAuthenticatorFunc(func(context.Context, string) (auth.Principal, error) {
		if authentications.Add(1) > 0 {
			return auth.Principal{}, auth.ErrUnauthenticated
		}
		return auth.Principal{AccountID: "viewer", SessionDigest: [32]byte{0: 1}}, nil
	})
	handler := newHandler(&rosterStub{}, notifier, authenticator, 10*time.Millisecond, time.Hour, time.Hour)
	server := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		handler.ServeHTTP(writer, testSessionRequest(request))
	}))
	defer server.Close()

	response, err := (&http.Client{Timeout: time.Second}).Get(server.URL)
	if err != nil {
		t.Fatal(err)
	}
	defer response.Body.Close()
	reader := bufio.NewReader(response.Body)
	_, _ = reader.ReadString('\n') // Initial roster data frame.
	_, _ = reader.ReadString('\n')
	body, err := reader.ReadString('\n')
	if err != nil || body != "event: session-expired\n" {
		t.Fatalf("expiration event = %q, err=%v", body, err)
	}
}

func TestStreamKeepsIdleConnectionAliveWithHeartbeatComments(t *testing.T) {
	notifier := NewNotifier()
	authenticator := sessionAuthenticatorFunc(func(context.Context, string) (auth.Principal, error) {
		return auth.Principal{AccountID: "viewer", SessionDigest: [32]byte{0: 1}}, nil
	})
	handler := newHandler(&rosterStub{}, notifier, authenticator, time.Hour, 10*time.Millisecond, time.Hour)
	server := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		handler.ServeHTTP(writer, testSessionRequest(request))
	}))
	defer server.Close()

	response, err := (&http.Client{Timeout: time.Second}).Get(server.URL)
	if err != nil {
		t.Fatal(err)
	}
	defer response.Body.Close()
	reader := bufio.NewReader(response.Body)
	_, _ = reader.ReadString('\n') // Initial roster data frame.
	_, _ = reader.ReadString('\n')
	if line, err := reader.ReadString('\n'); err != nil || line != ": keepalive\n" {
		t.Fatalf("heartbeat = %q, err=%v", line, err)
	}
}

func TestStreamClosesOnSessionRevalidationFailure(t *testing.T) {
	notifier := NewNotifier()
	var authentications atomic.Int32
	authenticator := sessionAuthenticatorFunc(func(context.Context, string) (auth.Principal, error) {
		authentications.Add(1)
		return auth.Principal{}, errors.New("session store unavailable")
	})
	handler := newHandler(&rosterStub{}, notifier, authenticator, 10*time.Millisecond, time.Hour, time.Hour)
	requestContext, cancel := context.WithTimeout(context.Background(), time.Second)
	defer cancel()
	request := testSessionRequest(httptest.NewRequest(http.MethodGet, "/", nil).WithContext(requestContext))
	request = request.WithContext(sessionapi.WithPrincipal(request.Context(), auth.Principal{AccountID: "viewer", SessionDigest: [32]byte{0: 1}}))
	recorder := httptest.NewRecorder()
	handler.ServeHTTP(recorder, request)
	if authentications.Load() == 0 {
		t.Fatal("session validation failure was not checked")
	}
}
