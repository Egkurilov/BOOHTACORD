package listmessagereactionsapi

import (
	"context"
	"encoding/json"
	"net/http/httptest"
	"testing"
	list "voice-platform/backend/internal/chat/list_message_reactions"
	auth "voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
)

type fakeLister struct {
	input list.Input
	calls int
}

func (f *fakeLister) List(_ context.Context, in list.Input) ([]list.Reaction, error) {
	f.input = in
	f.calls++
	return nil, nil
}
func TestReactionReadBindsCurrentDMActorAndRejectsAmbiguousQueries(t *testing.T) {
	for _, query := range []string{"", "?message_ids=", "?message_ids=one&message_ids=two", "?message_ids=message"} {
		f := &fakeLister{}
		r := httptest.NewRequest("GET", "/"+query, nil)
		r.SetPathValue("directMessageID", "pair")
		r = r.WithContext(sessionapi.WithPrincipal(r.Context(), auth.Principal{AccountID: "actor", Role: "ADMINISTRATOR"}))
		w := httptest.NewRecorder()
		NewHandler(f, true).ServeHTTP(w, r)
		if query != "?message_ids=message" {
			if w.Code != 400 || f.calls != 0 {
				t.Fatal("ambiguous query reached read")
			}
			continue
		}
		var body struct {
			Reactions []list.Reaction `json:"reactions"`
			CanPin    bool            `json:"can_pin"`
		}
		if err := json.Unmarshal(w.Body.Bytes(), &body); err != nil {
			t.Fatal(err)
		}
		if w.Code != 200 || w.Header().Get("Cache-Control") != "no-store" || body.CanPin || body.Reactions == nil || !f.input.Direct || f.input.ActorID != "actor" || f.input.ConversationID != "pair" {
			t.Fatal("DM read scope differs")
		}
	}
	f := &fakeLister{}
	w := httptest.NewRecorder()
	NewHandler(f, false).ServeHTTP(w, httptest.NewRequest("GET", "/?message_ids=message", nil))
	if w.Code != 403 || f.calls != 0 {
		t.Fatal("anonymous read accepted")
	}
}
