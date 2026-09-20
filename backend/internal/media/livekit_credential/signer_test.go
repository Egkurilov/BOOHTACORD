package livekitcredential

import (
	"encoding/base64"
	"encoding/json"
	"strings"
	"testing"
	"time"
)

func TestSignerCreatesShortRoomScopedNonAdminCredential(t *testing.T) {
	now := time.Date(2026, time.September, 17, 12, 0, 0, 0, time.UTC)
	signer, err := New(Config{URL: "wss://voice.example.test", APIKey: "key", APISecret: "secret"})
	if err != nil {
		t.Fatalf("New() error = %v", err)
	}
	signer.now = func() time.Time { return now }
	credential, err := signer.Issue("lease-1", "channel-1", "11111111-1111-4111-8111-111111111111")
	if err != nil || credential.Token == "" || credential.ExpiresAt != now.Add(validity) {
		t.Fatalf("Issue() error = %v, tokenEmpty = %t, expiresAt = %v", err, credential.Token == "", credential.ExpiresAt)
	}
	claims := decodeClaims(t, credential.Token)
	video := claims["video"].(map[string]any)
	if claims["sub"] != "voice-lease:lease-1" || claims["metadata"] != "account:11111111-1111-4111-8111-111111111111" || video["room"] != "voice:channel-1" || video["roomJoin"] != true || video["roomCreate"] != true || video["roomAdmin"] == true || video["canPublishData"] != false {
		t.Fatalf("claims = %#v", claims)
	}
	sources := strings.Join(strings.FieldsFunc(video["canPublishSources"].([]any)[0].(string)+","+video["canPublishSources"].([]any)[1].(string)+","+video["canPublishSources"].([]any)[2].(string), func(r rune) bool { return r == ',' }), ",")
	if sources != "microphone,screen_share,screen_share_audio" {
		t.Fatalf("sources = %q", sources)
	}
}

func TestSignerRejectsMissingSecretsOrNonWebSocketURL(t *testing.T) {
	for _, config := range []Config{{}, {URL: "https://voice.example.test", APIKey: "key", APISecret: "secret"}} {
		if _, err := New(config); err == nil {
			t.Fatalf("New(%#v) accepted invalid config", config)
		}
	}
}

func decodeClaims(t *testing.T, token string) map[string]any {
	t.Helper()
	parts := strings.Split(token, ".")
	if len(parts) != 3 {
		t.Fatalf("token parts = %d", len(parts))
	}
	payload, err := base64.RawURLEncoding.DecodeString(parts[1])
	if err != nil {
		t.Fatalf("decode token payload: %v", err)
	}
	var claims map[string]any
	if err := json.Unmarshal(payload, &claims); err != nil {
		t.Fatalf("unmarshal claims: %v", err)
	}
	return claims
}
