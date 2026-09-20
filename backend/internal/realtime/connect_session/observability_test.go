package connectsession

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/coder/websocket"
	"github.com/coder/websocket/wsjson"
	"voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
)

func TestHandlerObservesRealtimeLifecycle(t *testing.T) {
	observer := &connectionObserver{closed: make(chan struct{}), readyObserved: make(chan struct{})}
	handler := NewHandler(nil, 0, time.Now, nil, observer)
	server := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		handler.ServeHTTP(writer, request.WithContext(sessionapi.WithPrincipal(request.Context(), authenticatesession.Principal{AccountID: "user-1"})))
	}))
	defer server.Close()
	connection, _, err := websocket.Dial(context.Background(), "ws"+strings.TrimPrefix(server.URL, "http"), &websocket.DialOptions{HTTPHeader: http.Header{"Origin": {server.URL}}})
	if err != nil {
		t.Fatalf("Dial() error = %v", err)
	}
	var event Event
	if err := wsjson.Read(context.Background(), connection, &event); err != nil || event.Kind != "connection.ready" {
		t.Fatalf("ready event = %#v, error = %v", event, err)
	}
	select {
	case <-observer.readyObserved:
	case <-time.After(time.Second):
		t.Fatal("observer did not receive ready")
	}
	if opened, ready, closed := observer.counts(); opened != 1 || ready != 1 || closed != 0 {
		t.Fatalf("counts before close = %d, %d, %d", opened, ready, closed)
	}
	connection.CloseNow()
	select {
	case <-observer.closed:
	case <-time.After(time.Second):
		t.Fatal("observer did not receive close")
	}
	if opened, ready, closed := observer.counts(); opened != 1 || ready != 1 || closed != 1 {
		t.Fatalf("counts after close = %d, %d, %d", opened, ready, closed)
	}
}

type connectionObserver struct {
	closed        chan struct{}
	closedCount   int
	mutex         sync.Mutex
	opened        int
	ready         int
	readyObserved chan struct{}
}

func (observer *connectionObserver) RealtimeConnectionOpened() {
	observer.mutex.Lock()
	defer observer.mutex.Unlock()
	observer.opened++
}

func (observer *connectionObserver) ObserveRealtimeConnectionReady(time.Duration) {
	observer.mutex.Lock()
	observer.ready++
	observer.mutex.Unlock()
	close(observer.readyObserved)
}

func (observer *connectionObserver) RealtimeConnectionClosed() {
	observer.mutex.Lock()
	observer.closedCount++
	observer.mutex.Unlock()
	close(observer.closed)
}

func (observer *connectionObserver) counts() (int, int, int) {
	observer.mutex.Lock()
	defer observer.mutex.Unlock()
	return observer.opened, observer.ready, observer.closedCount
}
