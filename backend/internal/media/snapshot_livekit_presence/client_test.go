package snapshotlivekitpresence

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/livekit/protocol/auth"
)

const testRoom = "voice:11111111-1111-4111-8111-111111111111"

func TestSnapshotReadsConnectedParticipantsAndScreenTracks(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		claims := verifyGrant(t, request.Header.Get("Authorization"))
		writer.Header().Set("Content-Type", "application/json")
		switch request.URL.Path {
		case "/twirp/livekit.RoomService/ListRooms":
			if !claims.Video.RoomList || claims.Video.RoomAdmin {
				t.Fatal("room listing must have only room-list privilege")
			}
			_, _ = writer.Write([]byte(`{"rooms":[{"name":"` + testRoom + `"},{"name":"other:unrelated"}]}`))
		case "/twirp/livekit.RoomService/ListParticipants":
			if !claims.Video.RoomAdmin || claims.Video.Room != testRoom || claims.Video.RoomList {
				t.Fatal("participants request must have the exact room-admin grant")
			}
			_, _ = writer.Write([]byte(`{"participants":[{"tracks":[{"type":"VIDEO","source":"SCREEN_SHARE"},{"type":"AUDIO","source":"MICROPHONE"},{"type":"AUDIO","source":"SCREEN_SHARE_AUDIO"}]},{"tracks":[{"type":"VIDEO","source":"SCREEN_SHARE","muted":true}]}]}`))
		default:
			t.Fatalf("unexpected RoomService path %q", request.URL.Path)
		}
	}))
	defer server.Close()
	client, err := New(Config{URL: server.URL, APIKey: "test-key", APISecret: "test-secret"})
	if err != nil {
		t.Fatal(err)
	}
	snapshot, err := client.Snapshot(context.Background())
	if err != nil || snapshot != (Snapshot{Participants: 2, Streams: 3, ScreenStreams: 1}) {
		t.Fatalf("Snapshot() = %+v, %v", snapshot, err)
	}
}

func TestSnapshotFailsClosedOnPartialRoomServiceError(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		writer.Header().Set("Content-Type", "application/json")
		if strings.HasSuffix(request.URL.Path, "/ListRooms") {
			_, _ = writer.Write([]byte(`{"rooms":[{"name":"` + testRoom + `"}]}`))
			return
		}
		writer.WriteHeader(http.StatusServiceUnavailable)
		_, _ = writer.Write([]byte(`{"code":"unavailable","msg":"private failure"}`))
	}))
	defer server.Close()
	client, err := New(Config{URL: server.URL, APIKey: "test-key", APISecret: "test-secret"})
	if err != nil {
		t.Fatal(err)
	}
	snapshot, err := client.Snapshot(context.Background())
	if !errors.Is(err, ErrUnavailable) || snapshot != (Snapshot{}) {
		t.Fatalf("partial Snapshot() = %+v, %v", snapshot, err)
	}
}

func TestNewRejectsInvalidRoomServiceConfiguration(t *testing.T) {
	for _, config := range []Config{
		{URL: "wss://public.example", APIKey: "key", APISecret: "secret"},
		{URL: "http://livekit:7880", APISecret: "secret"},
		{URL: "http://livekit:7880", APIKey: "key"},
	} {
		if _, err := New(config); !errors.Is(err, ErrInvalidConfig) {
			t.Fatalf("invalid RoomService configuration error = %v", err)
		}
	}
}

func verifyGrant(t *testing.T, header string) *auth.ClaimGrants {
	t.Helper()
	if !strings.HasPrefix(header, "Bearer ") {
		t.Fatal("missing private RoomService bearer credential")
	}
	verifier, err := auth.ParseAPIToken(strings.TrimPrefix(header, "Bearer "))
	if err != nil || verifier.APIKey() != "test-key" {
		t.Fatal("wrong RoomService token")
	}
	_, grants, err := verifier.Verify("test-secret")
	if err != nil || grants.Video == nil {
		t.Fatal("invalid RoomService grant")
	}
	return grants
}
