package listtextpinsapi

import (
	"context"
	"encoding/json"
	"net/http/httptest"
	"testing"
	list "voice-platform/backend/internal/chat/list_text_pins"
	auth "voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
)

type fakeLister struct {
	input list.Input
	calls int
}

func (f *fakeLister) List(_ context.Context, in list.Input) (list.Result, error) {
	f.input = in
	f.calls++
	return list.Result{Pins: []list.Pin{}}, nil
}
func TestPinReadBindsCurrentActorRoleAndRejectsAmbiguousPaging(t *testing.T) {
	for _, query := range []string{"?limit=", "?limit=1&limit=2", "?before=", "?before=a&before=b", "?limit=invalid", "?limit=10"} {
		f := &fakeLister{}
		r := httptest.NewRequest("GET", "/"+query, nil)
		r.SetPathValue("channelID", "channel")
		r = r.WithContext(sessionapi.WithPrincipal(r.Context(), auth.Principal{AccountID: "actor", Role: "ADMINISTRATOR"}))
		w := httptest.NewRecorder()
		NewHandler(f).ServeHTTP(w, r)
		if query != "?limit=10" {
			if w.Code != 400 || f.calls != 0 {
				t.Fatal("ambiguous paging reached read")
			}
			continue
		}
		var page list.Result
		if err := json.Unmarshal(w.Body.Bytes(), &page); err != nil {
			t.Fatal(err)
		}
		if w.Code != 200 || w.Header().Get("Cache-Control") != "no-store" || !page.CanManage || f.input.ActorID != "actor" || f.input.ChannelID != "channel" || f.input.Limit != 10 {
			t.Fatal("pin scope differs")
		}
	}
	f := &fakeLister{}
	w := httptest.NewRecorder()
	NewHandler(f).ServeHTTP(w, httptest.NewRequest("GET", "/", nil))
	if w.Code != 403 || f.calls != 0 {
		t.Fatal("anonymous read accepted")
	}
}
