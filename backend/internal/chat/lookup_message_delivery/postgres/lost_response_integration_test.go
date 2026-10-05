package deliverypostgres

import (
	"bytes"
	"encoding/json"
	"github.com/google/uuid"
	"net/http"
	"net/http/httptest"
	"testing"
	create "voice-platform/backend/internal/chat/create_text_message"
	createapi "voice-platform/backend/internal/chat/create_text_message/api"
	createpostgres "voice-platform/backend/internal/chat/create_text_message/postgres"
	deliveryapi "voice-platform/backend/internal/chat/lookup_message_delivery/api"
	auth "voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	fixture "voice-platform/backend/internal/testsupport/guild_lifecycle"
)

func TestLostHTTPResponseCanBeReconciledAndExactRetryStoresOneRow(t *testing.T) {
	f := fixture.New(t)
	client := uuid.NewString()
	creator := createapi.NewHandler(create.New(createpostgres.New(createpostgres.NewPoolDatabase(f.Pool))))
	lookup := deliveryapi.New(New(f.Pool), false)
	mux := http.NewServeMux()
	drop := true
	mux.HandleFunc("POST /channels/{channelID}/messages", func(w http.ResponseWriter, r *http.Request) {
		if !drop {
			creator.ServeHTTP(w, r)
			return
		}
		recorded := httptest.NewRecorder()
		creator.ServeHTTP(recorded, r)
		if recorded.Code != 201 {
			t.Error("fixture POST did not commit")
		}
		drop = false
		socket, _, err := w.(http.Hijacker).Hijack()
		if err != nil {
			t.Error("fixture lost-response transport failed")
			return
		}
		socket.Close()
	})
	mux.Handle("GET /channels/{channelID}/message-delivery/{clientMessageID}", lookup)
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		mux.ServeHTTP(w, r.WithContext(sessionapi.WithPrincipal(r.Context(), auth.Principal{AccountID: f.Admin, Role: "ADMINISTRATOR"})))
	}))
	defer server.Close()
	payload, _ := json.Marshal(map[string]string{"client_message_id": client, "body": "fixture"})
	post := func() (*http.Response, error) {
		return http.Post(server.URL+"/channels/"+f.Channel+"/messages", "application/json", bytes.NewReader(payload))
	}
	if response, err := post(); err == nil {
		response.Body.Close()
		t.Fatal("fixture failed to drop committed HTTP response")
	}
	response, err := http.Get(server.URL + "/channels/" + f.Channel + "/message-delivery/" + client)
	if err != nil {
		t.Fatal("delivery lookup transport failed")
	}
	var receipt struct {
		ID *string `json:"message_id"`
	}
	err = json.NewDecoder(response.Body).Decode(&receipt)
	response.Body.Close()
	if err != nil || response.StatusCode != 200 || receipt.ID == nil {
		t.Fatal("committed message missing from caller receipt")
	}
	response, err = post()
	if err != nil {
		t.Fatal("exact retry transport failed")
	}
	response.Body.Close()
	var count int
	if err = f.Pool.QueryRow(f.Context, `SELECT count(*) FROM messages WHERE channel_id=$1 AND author_id=$2 AND client_message_id=$3`, f.Channel, f.Admin, client).Scan(&count); err != nil || count != 1 {
		t.Fatal("retry duplicated committed message", err)
	}
}
