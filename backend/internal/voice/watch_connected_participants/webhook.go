package watchconnectedparticipants

import (
	"crypto/sha256"
	"crypto/subtle"
	"encoding/base64"
	"encoding/json"
	"io"
	"net/http"
	"strings"

	"github.com/livekit/protocol/auth"
)

// Only LiveKit's signed callback can invalidate connected-room snapshots.
// Snapshot data is never trusted from a webhook payload.
func NewWebhookHandler(key, secret string, notifier *Notifier) http.Handler {
	return http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		if request.Method != http.MethodPost {
			writer.WriteHeader(http.StatusMethodNotAllowed)
			return
		}
		request.Body = http.MaxBytesReader(writer, request.Body, 64<<10)
		body, err := io.ReadAll(request.Body)
		if err != nil {
			writer.WriteHeader(http.StatusBadRequest)
			return
		}
		token, err := auth.ParseAPIToken(request.Header.Get("Authorization"))
		if err != nil || token.APIKey() != key {
			writer.WriteHeader(http.StatusUnauthorized)
			return
		}
		_, claims, err := token.Verify(secret)
		if err != nil {
			writer.WriteHeader(http.StatusUnauthorized)
			return
		}
		hash := sha256.Sum256(body)
		if subtle.ConstantTimeCompare([]byte(claims.Sha256), []byte(base64.StdEncoding.EncodeToString(hash[:]))) != 1 {
			writer.WriteHeader(http.StatusUnauthorized)
			return
		}
		var event struct {
			Event string `json:"event"`
			Room  struct {
				Name string `json:"name"`
			} `json:"room"`
		}
		if json.Unmarshal(body, &event) != nil {
			writer.WriteHeader(http.StatusBadRequest)
			return
		}
		if strings.HasPrefix(event.Room.Name, "voice:") {
			switch event.Event {
			case "room_started", "room_finished", "participant_joined", "participant_left",
				"participant_connection_aborted", "track_published", "track_unpublished":
				notifier.Notify()
			}
		}
		writer.WriteHeader(http.StatusNoContent)
	})
}
