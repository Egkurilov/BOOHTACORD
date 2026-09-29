package watchconnectedparticipants

import (
	"crypto/sha256"
	"encoding/base64"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/livekit/protocol/auth"
)

func TestWebhookRequiresSignatureAndNotifiesVoiceRooms(t *testing.T) {
	notifier := NewNotifier()
	updates, done := notifier.Subscribe()
	defer done()
	handler := NewWebhookHandler("key", "secret", notifier)
	body := `{"event":"participant_joined","room":{"name":"voice:11111111-1111-4111-8111-111111111111"}}`
	unsigned := httptest.NewRecorder()
	handler.ServeHTTP(unsigned, httptest.NewRequest(http.MethodPost, "/internal/livekit/roster", strings.NewReader(body)))
	if unsigned.Code != http.StatusUnauthorized {
		t.Fatalf("unsigned status=%d", unsigned.Code)
	}
	select {
	case <-updates:
		t.Fatal("unsigned event notified")
	default:
	}
	hash := sha256.Sum256([]byte(body))
	token, err := auth.NewAccessToken("key", "secret").SetSha256(base64.StdEncoding.EncodeToString(hash[:])).ToJWT()
	if err != nil {
		t.Fatal(err)
	}
	request := httptest.NewRequest(http.MethodPost, "/internal/livekit/roster", strings.NewReader(body))
	request.Header.Set("Authorization", token)
	recorder := httptest.NewRecorder()
	handler.ServeHTTP(recorder, request)
	if recorder.Code != http.StatusNoContent {
		t.Fatalf("signed status=%d", recorder.Code)
	}
	select {
	case <-updates:
	default:
		t.Fatal("signed voice event did not notify")
	}
}
