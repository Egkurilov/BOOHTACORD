package snapshotlivekitpresence

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"
)

type callObserver struct {
	methods  []string
	failures []bool
}

func (o *callObserver) ObserveSFURoomServiceCall(method string, failed bool) {
	o.methods = append(o.methods, method)
	o.failures = append(o.failures, failed)
}

func TestRoomServiceObserverRecordsBoundedMethodAndOutcome(t *testing.T) {
	fail := false
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		if fail {
			w.WriteHeader(503)
			_, _ = w.Write([]byte(`{"code":"unavailable","msg":"private"}`))
			return
		}
		_, _ = w.Write([]byte(`{"rooms":[]}`))
	}))
	defer server.Close()
	client, _ := New(Config{URL: server.URL, APIKey: "test", APISecret: "test"})
	observer := &callObserver{}
	client = client.WithObserver(observer)
	_, _ = client.SnapshotRooms(context.Background(), []string{"11111111-1111-4111-8111-111111111111"})
	fail = true
	_, _ = client.SnapshotRooms(context.Background(), []string{"11111111-1111-4111-8111-111111111111"})
	if len(observer.methods) != 2 || observer.methods[0] != "ListRooms" || observer.failures[0] || !observer.failures[1] {
		t.Fatal("RoomService calls were not measured with bounded outcomes")
	}
}
