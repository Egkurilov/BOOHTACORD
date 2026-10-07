package screenpreviewlivekit

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/google/uuid"
)

func TestCurrentTrackRequiresExactActiveScreenPublication(t *testing.T) {
	channelID, leaseID := uuid.NewString(), uuid.NewString()
	var requestPath, authorization string
	server := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		requestPath, authorization = request.URL.Path, request.Header.Get("Authorization")
		writer.Header().Set("Content-Type", "application/json")
		_, _ = writer.Write([]byte(`{"participants":[{"identity":"voice-lease:` + leaseID + `","state":"ACTIVE","tracks":[{"sid":"screen-track-1","type":"VIDEO","source":"SCREEN_SHARE","muted":false}]}]}`))
	}))
	defer server.Close()
	client, err := New(Config{URL: server.URL, APIKey: "api-key", APISecret: "api-secret"})
	if err != nil {
		t.Fatal(err)
	}
	track, err := client.CurrentTrack(context.Background(), channelID, leaseID)
	if err != nil || track != "screen-track-1" {
		t.Fatalf("track = %q, err = %v", track, err)
	}
	if requestPath != "/twirp/livekit.RoomService/ListParticipants" || !strings.HasPrefix(authorization, "Bearer ") {
		t.Fatalf("RoomService request was not authenticated: %q %q", requestPath, authorization)
	}
}

func TestCurrentTrackFailsClosedForMissingMutedOrAmbiguousPublication(t *testing.T) {
	channelID, leaseID := uuid.NewString(), uuid.NewString()
	cases := map[string]string{
		"missing":   `{"participants":[{"identity":"voice-lease:` + leaseID + `","state":"ACTIVE","tracks":[]}]}`,
		"muted":     `{"participants":[{"identity":"voice-lease:` + leaseID + `","state":"ACTIVE","tracks":[{"sid":"a","type":"VIDEO","source":"SCREEN_SHARE","muted":true}]}]}`,
		"ambiguous": `{"participants":[{"identity":"voice-lease:` + leaseID + `","state":"ACTIVE","tracks":[{"sid":"a","type":"VIDEO","source":"SCREEN_SHARE"},{"sid":"b","type":"VIDEO","source":"SCREEN_SHARE"}]}]}`,
	}
	for name, payload := range cases {
		t.Run(name, func(t *testing.T) {
			server := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, _ *http.Request) { _, _ = writer.Write([]byte(payload)) }))
			defer server.Close()
			client, err := New(Config{URL: server.URL, APIKey: "api-key", APISecret: "api-secret"})
			if err != nil {
				t.Fatal(err)
			}
			if _, err := client.CurrentTrack(context.Background(), channelID, leaseID); !errors.Is(err, ErrNoPublication) {
				t.Fatalf("error = %v", err)
			}
		})
	}
}

func TestCurrentTrackRejectsInvalidIdentifiersAndUnavailableService(t *testing.T) {
	client, err := New(Config{URL: "http://127.0.0.1:1", APIKey: "api-key", APISecret: "api-secret"})
	if err != nil {
		t.Fatal(err)
	}
	if _, err := client.CurrentTrack(context.Background(), "not-a-channel", uuid.NewString()); !errors.Is(err, ErrUnavailable) {
		t.Fatalf("invalid channel error = %v", err)
	}
	if _, err := client.CurrentTrack(context.Background(), uuid.NewString(), uuid.NewString()); !errors.Is(err, ErrUnavailable) {
		t.Fatalf("unavailable service error = %v", err)
	}
}
