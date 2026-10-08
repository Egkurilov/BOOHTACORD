package archivereadonlytextapi

import (
	"context"
	"net/http/httptest"
	"strings"
	"testing"
	action "voice-platform/backend/internal/channel/archive_readonly_text"
	identity "voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
)

type fakeChanger struct {
	calls int
	input action.Input
	err   error
}

func (s *fakeChanger) Archive(_ context.Context, in action.Input) (action.Result, error) {
	s.calls++
	s.input = in
	return action.Result{ID: in.ChannelID, Revision: 3}, s.err
}
func TestMutationAdminRoleStrictBodyAndRevisionConflict(t *testing.T) {
	for _, c := range []struct {
		role, body    string
		err           error
		status, calls int
	}{
		{"MEMBER", `{"expected_revision":2,"confirm":true}`, nil, 403, 0},
		{"ADMINISTRATOR", `{"expected_revision":2,"extra":1}`, nil, 400, 0},
		{"ADMINISTRATOR", `{"expected_revision":2} {}`, nil, 400, 0},
		{"ADMINISTRATOR", `{"expected_revision":2,"confirm":true}`, action.ErrConflict, 409, 1},
		{"ADMINISTRATOR", `{"expected_revision":2,"confirm":true}`, nil, 200, 1},
	} {
		s := &fakeChanger{err: c.err}
		r := httptest.NewRequest("POST", "/", strings.NewReader(c.body))
		r.SetPathValue("channelID", "22222222-2222-4222-8222-222222222222")
		r = r.WithContext(sessionapi.WithPrincipal(r.Context(), identity.Principal{AccountID: "11111111-1111-4111-8111-111111111111", Role: c.role}))
		w := httptest.NewRecorder()
		NewHandler(s).ServeHTTP(w, r)
		if w.Code != c.status || s.calls != c.calls {
			t.Fatalf("role=%s body=%s status=%d calls=%d", c.role, c.body, w.Code, s.calls)
		}
	}
}
