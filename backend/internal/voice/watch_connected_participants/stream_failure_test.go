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

type failingRefreshLister struct{ calls atomic.Int32 }

func (lister *failingRefreshLister) List(context.Context, string) (roster.Result, error) {
	if lister.calls.Add(1) == 1 {
		return roster.Result{Channels: []roster.ChannelRoster{}}, nil
	}
	return roster.Result{}, errors.New("private dependency failure: account-123 room-456")
}

type failureStageObserver struct{ stages chan string }

func (observer *failureStageObserver) ObserveVoiceRosterFailure(stage string) {
	observer.stages <- stage
}

func TestInitialSnapshotFailureStaysUnavailableAndHidesDependencyDetails(t *testing.T) {
	handler := NewHandler(errorLister{}, NewNotifier(), sessionAuthenticatorFunc(func(context.Context, string) (auth.Principal, error) {
		return auth.Principal{}, nil
	}))
	recorder := httptest.NewRecorder()
	request := testSessionRequest(httptest.NewRequest(http.MethodGet, "/", nil))
	handler.ServeHTTP(recorder, request)
	if recorder.Code != http.StatusServiceUnavailable || strings.Contains(recorder.Body.String(), "private dependency") {
		t.Fatalf("status=%d body=%q", recorder.Code, recorder.Body.String())
	}
}

type errorLister struct{}

func (errorLister) List(context.Context, string) (roster.Result, error) {
	return roster.Result{}, errors.New("private dependency failure: account-123 room-456")
}

func TestRefreshFailureEmitsBoundedEventAndClosesWithoutEmptyRoster(t *testing.T) {
	notifier, lister, observer := NewNotifier(), &failingRefreshLister{}, &failureStageObserver{stages: make(chan string, 2)}
	handler := newHandler(lister, notifier, sessionAuthenticatorFunc(func(context.Context, string) (auth.Principal, error) {
		return auth.Principal{AccountID: "viewer"}, nil
	}), time.Hour, time.Hour, time.Hour, observer)
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
	first, _ := reader.ReadString('\n')
	_, _ = reader.ReadString('\n')
	if first != "data: {\"channels\":[]}\n" {
		t.Fatalf("successful empty snapshot = %q", first)
	}
	notifier.Notify()
	frame, err := io.ReadAll(reader)
	if err != nil {
		t.Fatal(err)
	}
	body := string(frame)
	if body != "event: roster-unavailable\ndata: {}\n\n" || strings.Contains(body, "channels") || strings.Contains(body, "session-expired") || strings.Contains(body, "account-123") {
		t.Fatalf("failure frame=%q", body)
	}
	select {
	case stage := <-observer.stages:
		if stage != "stream_snapshot" {
			t.Fatalf("observed failure stage=%q", stage)
		}
	default:
		t.Fatal("snapshot failure was not observed")
	}
}

func TestSessionStoreFailureClosesWithoutRosterStatus(t *testing.T) {
	notifier, observer := NewNotifier(), &failureStageObserver{stages: make(chan string, 1)}
	handler := newHandler(&rosterStub{}, notifier, sessionAuthenticatorFunc(func(context.Context, string) (auth.Principal, error) {
		return auth.Principal{}, errors.New("private session store detail")
	}), time.Millisecond, time.Hour, time.Hour, observer)
	server := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		handler.ServeHTTP(writer, testSessionRequest(request))
	}))
	defer server.Close()
	response, err := (&http.Client{Timeout: time.Second}).Get(server.URL)
	if err != nil {
		t.Fatal(err)
	}
	defer response.Body.Close()
	body, err := io.ReadAll(response.Body)
	if err != nil || strings.Contains(string(body), "session-expired") || strings.Contains(string(body), "private session") {
		t.Fatalf("session-store stream body=%q err=%v", body, err)
	}
	if stage := <-observer.stages; stage != "stream_session_store" {
		t.Fatalf("observed failure stage=%q", stage)
	}
}
