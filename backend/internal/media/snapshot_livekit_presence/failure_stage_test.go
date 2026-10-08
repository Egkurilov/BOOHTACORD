package snapshotlivekitpresence

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestSnapshotRoomsReturnsBoundedFailureStages(t *testing.T) {
	for _, test := range []struct {
		name, room, failedPath, want string
	}{
		{name: "invalid room ID", room: "bad", want: "validation"},
		{name: "room list failure", room: strings.TrimPrefix(testRoom, "voice:"), failedPath: "/ListRooms", want: "room_list"},
		{name: "participant list failure", room: strings.TrimPrefix(testRoom, "voice:"), failedPath: "/ListParticipants", want: "participants"},
	} {
		t.Run(test.name, func(t *testing.T) {
			server := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
				if strings.HasSuffix(request.URL.Path, "/ListRooms") && test.failedPath != "/ListRooms" {
					_, _ = writer.Write([]byte(`{"rooms":[{"name":"` + testRoom + `"}]}`))
					return
				}
				writer.WriteHeader(http.StatusServiceUnavailable)
			}))
			defer server.Close()
			client, _ := New(Config{URL: server.URL, APIKey: "key", APISecret: "secret"})
			_, err := client.SnapshotRooms(context.Background(), []string{test.room})
			if FailureStage(err) != test.want {
				t.Fatalf("failure stage=%q error=%v want=%q", FailureStage(err), err, test.want)
			}
		})
	}
}
