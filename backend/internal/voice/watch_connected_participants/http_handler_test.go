package watchconnectedparticipants

import (
	"bufio"
	"context"
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
