package watchconnectedparticipants

import (
	"bufio"
	"context"
	"fmt"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	auth "voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
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

func (stub *notifyingRosterStub) List(_ context.Context, _ string) (roster.Result, error) {
	stub.calls++
	if stub.calls == 1 {
		// Model a participant change while the initial roster is being loaded.
		stub.notifier.Notify()
	}
	return roster.Result{Channels: []roster.ChannelRoster{{ChannelID: fmt.Sprintf("snapshot-%d", stub.calls)}}}, nil
}

func TestStreamSendsAuthorizedSnapshotAndUpdatesOnNotification(t *testing.T) {
	notifier, lister := NewNotifier(), &rosterStub{}
	server := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		request = request.WithContext(sessionapi.WithPrincipal(request.Context(), auth.Principal{AccountID: "viewer"}))
		NewHandler(lister, notifier).ServeHTTP(writer, request)
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
	if err != nil || !strings.Contains(first, `"channel_id":"room"`) || lister.actor != "viewer" {
		t.Fatalf("first=%s err=%v actor=%s", first, err, lister.actor)
	}
	_, _ = reader.ReadString('\n') // SSE frame separator
	notifier.Notify()
	second, err := reader.ReadString('\n')
	if err != nil || !strings.Contains(second, `"channel_id":"room"`) {
		t.Fatalf("second=%s err=%v", second, err)
	}
}

func TestStreamDoesNotMissChangeDuringInitialSnapshot(t *testing.T) {
	notifier := NewNotifier()
	lister := &notifyingRosterStub{notifier: notifier}
	server := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		request = request.WithContext(sessionapi.WithPrincipal(request.Context(), auth.Principal{AccountID: "viewer"}))
		NewHandler(lister, notifier).ServeHTTP(writer, request)
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
	request = request.WithContext(sessionapi.WithPrincipal(requestContext, auth.Principal{AccountID: "viewer"}))
	NewHandler(lister, notifier).ServeHTTP(httptest.NewRecorder(), request)

	if !lister.hasDeadline {
		t.Fatal("initial roster snapshot did not receive a bounded context")
	}
	remaining := time.Until(lister.deadlineAt)
	if remaining <= 0 || remaining > 5*time.Second {
		t.Fatalf("initial snapshot deadline remaining = %s, want <= 5s", remaining)
	}
}
