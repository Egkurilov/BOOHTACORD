package watchconnectedparticipants

import (
	"bufio"
	"context"
	"errors"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync/atomic"
	"testing"
	"time"

	auth "voice-platform/backend/internal/identity/authenticate_session"
	roster "voice-platform/backend/internal/voice/list_connected_participants"
)

type recoveringLister struct{ calls atomic.Int32 }

func (lister *recoveringLister) List(context.Context, string) (roster.Result, error) {
	switch lister.calls.Add(1) {
	case 1:
		return roster.Result{Channels: []roster.ChannelRoster{}}, nil
	case 2:
		return roster.Result{}, errors.New("temporary dependency failure")
	default:
		return roster.Result{Channels: []roster.ChannelRoster{{ChannelID: "recovered"}}}, nil
	}
}

func TestReconnectLoadsFreshRosterAfterTransientFailure(t *testing.T) {
	notifier, lister := NewNotifier(), &recoveringLister{}
	handler := NewHandler(lister, notifier, sessionAuthenticatorFunc(func(context.Context, string) (auth.Principal, error) {
		return auth.Principal{AccountID: "viewer"}, nil
	}))
	server := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		handler.ServeHTTP(writer, testSessionRequest(request))
	}))
	defer server.Close()
	client := &http.Client{Timeout: time.Second}
	first, err := client.Get(server.URL)
	if err != nil {
		t.Fatal(err)
	}
	reader := bufio.NewReader(first.Body)
	_, _ = reader.ReadString('\n')
	_, _ = reader.ReadString('\n')
	notifier.Notify()
	failure, err := io.ReadAll(reader)
	first.Body.Close()
	if err != nil || !strings.Contains(string(failure), "event: roster-unavailable\ndata: {}") {
		t.Fatalf("transient failure frame=%q err=%v", failure, err)
	}
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	request, _ := http.NewRequestWithContext(ctx, http.MethodGet, server.URL, nil)
	second, err := client.Do(request)
	if err != nil {
		t.Fatal(err)
	}
	defer second.Body.Close()
	line, err := bufio.NewReader(second.Body).ReadString('\n')
	cancel()
	if err != nil || !strings.Contains(line, `"channel_id":"recovered"`) {
		t.Fatalf("reconnected snapshot=%q err=%v", line, err)
	}
}
