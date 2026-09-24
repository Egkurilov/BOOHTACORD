package snapshotlivekitpresence

import (
	"context"
	"errors"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestCountRoomParticipantsUsesExactRoomScopedPrivileges(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		claims := verifyGrant(t, request.Header.Get("Authorization"))
		writer.Header().Set("Content-Type", "application/json")
		switch request.URL.Path {
		case "/twirp/livekit.RoomService/ListRooms":
			if !claims.Video.RoomList || claims.Video.RoomAdmin || !strings.Contains(readBody(t, request), `"names":["`+testRoom+`"]`) {
				t.Fatal("room listing was not exact and least-privileged")
			}
			_, _ = writer.Write([]byte(`{"rooms":[{"name":"` + testRoom + `"}]}`))
		case "/twirp/livekit.RoomService/ListParticipants":
			if !claims.Video.RoomAdmin || claims.Video.RoomList || claims.Video.Room != testRoom {
				t.Fatal("participants request was not room-scoped")
			}
			_, _ = writer.Write([]byte(`{"participants":[{},{}]}`))
		default:
			t.Fatalf("unexpected RoomService path %q", request.URL.Path)
		}
	}))
	defer server.Close()
	client, _ := New(Config{URL: server.URL, APIKey: "test-key", APISecret: "test-secret"})
	count, err := client.CountRoomParticipants(context.Background(), strings.TrimPrefix(testRoom, "voice:"))
	if err != nil || count != 2 {
		t.Fatalf("count=%d err=%v", count, err)
	}
}

func TestCountRoomParticipantsTrustsAuthoritativeAbsenceOnly(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		if !strings.HasSuffix(request.URL.Path, "/ListRooms") {
			t.Fatal("queried participants for absent room")
		}
		writer.Header().Set("Content-Type", "application/json")
		_, _ = writer.Write([]byte(`{"rooms":[]}`))
	}))
	defer server.Close()
	client, _ := New(Config{URL: server.URL, APIKey: "test-key", APISecret: "test-secret"})
	count, err := client.CountRoomParticipants(context.Background(), strings.TrimPrefix(testRoom, "voice:"))
	if err != nil || count != 0 {
		t.Fatalf("count=%d err=%v", count, err)
	}
}

func TestCountRoomParticipantsFailsClosedOnRoomServiceError(t *testing.T) {
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
	client, _ := New(Config{URL: server.URL, APIKey: "test-key", APISecret: "test-secret"})
	count, err := client.CountRoomParticipants(context.Background(), strings.TrimPrefix(testRoom, "voice:"))
	if count != 0 || !errors.Is(err, ErrUnavailable) {
		t.Fatalf("count=%d err=%v", count, err)
	}
	count, err = client.CountRoomParticipants(context.Background(), "not-a-uuid")
	if count != 0 || !errors.Is(err, ErrUnavailable) {
		t.Fatalf("invalid ID count=%d err=%v", count, err)
	}
}

func readBody(t *testing.T, request *http.Request) string {
	t.Helper()
	buffer, err := io.ReadAll(request.Body)
	if err != nil {
		t.Fatal(err)
	}
	return string(buffer)
}
