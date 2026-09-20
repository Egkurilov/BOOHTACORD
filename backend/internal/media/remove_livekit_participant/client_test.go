package removelivekitparticipant

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/livekit/protocol/auth"
)

const (
	testAPIKey    = "test-key"
	testAPISecret = "test-secret"
	testLeaseID   = "11111111-1111-4111-8111-111111111111"
	testChannelID = "22222222-2222-4222-8222-222222222222"
)

func TestRemoveUsesPrivateRoomServiceCredential(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		if request.URL.Path != "/twirp/livekit.RoomService/RemoveParticipant" {
			t.Fatalf("path = %q", request.URL.Path)
		}
		verifyRoomServiceToken(t, request.Header.Get("Authorization"))
		var body struct {
			Room     string `json:"room"`
			Identity string `json:"identity"`
		}
		if err := json.NewDecoder(request.Body).Decode(&body); err != nil {
			t.Fatalf("decode request: %v", err)
		}
		if body.Room != "voice:"+testChannelID || body.Identity != "voice-lease:"+testLeaseID {
			t.Fatalf("body = %#v", body)
		}
		writer.Header().Set("Content-Type", "application/json")
		_, _ = writer.Write([]byte("{}"))
	}))
	defer server.Close()

	client, err := New(Config{URL: server.URL, APIKey: testAPIKey, APISecret: testAPISecret})
	if err != nil {
		t.Fatalf("New() error = %v", err)
	}
	if err := client.Remove(context.Background(), testLeaseID, testChannelID); err != nil {
		t.Fatalf("Remove() error = %v", err)
	}
}

func TestRemoveMapsAbsentParticipantSeparately(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, _ *http.Request) {
		writer.Header().Set("Content-Type", "application/json")
		writer.WriteHeader(http.StatusNotFound)
		_, _ = writer.Write([]byte(`{"code":"not_found","msg":"participant not found"}`))
	}))
	defer server.Close()
	client, err := New(Config{URL: server.URL, APIKey: testAPIKey, APISecret: testAPISecret})
	if err != nil {
		t.Fatalf("New() error = %v", err)
	}
	if err := client.Remove(context.Background(), testLeaseID, testChannelID); !errors.Is(err, ErrParticipantAbsent) {
		t.Fatalf("Remove() error = %v, want ErrParticipantAbsent", err)
	}
}

func TestNewRejectsPublicSignalOrIncompleteConfiguration(t *testing.T) {
	for name, config := range map[string]Config{
		"websocket URL":  {URL: "wss://voice.example.test", APIKey: testAPIKey, APISecret: testAPISecret},
		"missing key":    {URL: "http://livekit:7880", APISecret: testAPISecret},
		"missing secret": {URL: "http://livekit:7880", APIKey: testAPIKey},
	} {
		t.Run(name, func(t *testing.T) {
			if _, err := New(config); !errors.Is(err, ErrInvalidConfig) {
				t.Fatalf("New() error = %v, want ErrInvalidConfig", err)
			}
		})
	}
}

func verifyRoomServiceToken(t *testing.T, header string) {
	t.Helper()
	if !strings.HasPrefix(header, "Bearer ") {
		t.Fatalf("authorization scheme = %q", header)
	}
	verifier, err := auth.ParseAPIToken(strings.TrimPrefix(header, "Bearer "))
	if err != nil || verifier.APIKey() != testAPIKey {
		t.Fatal("RoomService request did not carry a token signed for the configured API key")
	}
	_, claims, err := verifier.Verify(testAPISecret)
	if err != nil || claims.Video == nil || !claims.Video.RoomAdmin || claims.Video.Room != "voice:"+testChannelID {
		t.Fatal("RoomService token did not have the expected private room-admin grant")
	}
}
