package changetextpinapi

import (
	"context"
	"net/http/httptest"
	"testing"
	action "voice-platform/backend/internal/chat/change_text_pin"
	identity "voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
)

type fakeChanger struct {
	calls int
	input action.Input
}

func (f *fakeChanger) Set(_ context.Context, in action.Input) (action.Result, error) {
	f.calls++
	f.input = in
	return action.Result{}, nil
}
func TestPinOnlyAdminWithExplicitDesiredMethod(t *testing.T) {
	for _, role := range []string{"MEMBER", "ADMINISTRATOR"} {
		for _, method := range []string{"PUT", "DELETE"} {
			f := &fakeChanger{}
			r := httptest.NewRequest(method, "/", nil)
			r.SetPathValue("channelID", "22222222-2222-4222-8222-222222222222")
			r.SetPathValue("messageID", "33333333-3333-4333-8333-333333333333")
			r = r.WithContext(sessionapi.WithPrincipal(r.Context(), identity.Principal{AccountID: "11111111-1111-4111-8111-111111111111", Role: role}))
			w := httptest.NewRecorder()
			NewHandler(f).ServeHTTP(w, r)
			if role == "MEMBER" {
				if w.Code != 403 || f.calls != 0 {
					t.Fatal("member pin accepted")
				}
			} else if w.Code != 204 || f.input.Present != (method == "PUT") {
				t.Fatal("admin desired state lost")
			}
		}
	}
}
