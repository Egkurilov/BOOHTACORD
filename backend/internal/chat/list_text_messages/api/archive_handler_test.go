package listtextmessagesapi

import (
	"context"
	"net/http/httptest"
	"testing"
	list "voice-platform/backend/internal/chat/list_text_messages"
	identity "voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
)

func TestArchiveHistoryUsesSessionActorAndCannotForgeModeOnLiveHandler(t *testing.T) {
	for _, archive := range []bool{false, true} {
		var input list.Input
		lister := listerFunc(func(_ context.Context, in list.Input) (list.Result, error) {
			input = in
			return list.Result{Messages: []list.Message{}}, nil
		})
		handler := NewHandler(lister)
		if archive {
			handler = NewArchiveHandler(lister)
		}
		r := httptest.NewRequest("GET", "/messages?read_archive=true", nil)
		r.SetPathValue("channelID", "22222222-2222-4222-8222-222222222222")
		r = r.WithContext(sessionapi.WithPrincipal(r.Context(), identity.Principal{AccountID: "11111111-1111-4111-8111-111111111111"}))
		w := httptest.NewRecorder()
		handler.ServeHTTP(w, r)
		if w.Code != 200 || input.ReadArchive != archive || archive && input.ActorID != "11111111-1111-4111-8111-111111111111" {
			t.Fatalf("input=%+v status=%d", input, w.Code)
		}
	}
}
