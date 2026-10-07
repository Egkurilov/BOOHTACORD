package publishscreendescriptorlivekit

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/livekit/protocol/auth"
)

const testLease = "11111111-1111-4111-8111-111111111111"
const testChannel = "22222222-2222-4222-8222-222222222222"

func TestPublishUpdatesOnlyTheScreenDescriptorAttribute(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		if request.URL.Path != "/twirp/livekit.RoomService/UpdateParticipant" {
			t.Fatalf("path = %q", request.URL.Path)
		}
		verifyToken(t, request.Header.Get("Authorization"))
		var body map[string]json.RawMessage
		if err := json.NewDecoder(request.Body).Decode(&body); err != nil {
			t.Fatal(err)
		}
		if len(body) != 3 || body["metadata"] != nil || body["name"] != nil || body["permission"] != nil {
			t.Fatalf("request would modify unrelated participant fields: %s", body)
		}
		var attributes map[string]string
		if err := json.Unmarshal(body["attributes"], &attributes); err != nil {
			t.Fatal(err)
		}
		if len(attributes) != 1 || attributes[descriptorAttribute] != `{"schema_version":1}` {
			t.Fatalf("attributes = %#v", attributes)
		}
		writer.Header().Set("Content-Type", "application/json")
		_, _ = writer.Write([]byte(`{"sid":"participant"}`))
	}))
	defer server.Close()
	writer, err := New(Config{URL: server.URL, APIKey: "test-key", APISecret: "test-secret"})
	if err != nil {
		t.Fatal(err)
	}
	if err := writer.Publish(context.Background(), testLease, testChannel, `{"schema_version":1}`); err != nil {
		t.Fatal(err)
	}
}

func TestNewRejectsInvalidPrivateEndpoint(t *testing.T) {
	if _, err := New(Config{URL: "wss://example.test", APIKey: "key", APISecret: "secret"}); err == nil {
		t.Fatal("expected invalid configuration")
	}
}

func verifyToken(t *testing.T, value string) {
	t.Helper()
	const prefix = "Bearer "
	if len(value) <= len(prefix) || value[:len(prefix)] != prefix {
		t.Fatalf("authorization = %q", value)
	}
	parsed, err := auth.ParseAPIToken(value[len(prefix):])
	if err != nil {
		t.Fatal(err)
	}
	_, claims, err := parsed.Verify("test-secret")
	if err != nil || claims.Video == nil || !claims.Video.RoomAdmin || claims.Video.Room != "voice:"+testChannel {
		t.Fatal("token has wrong room grant")
	}
}
