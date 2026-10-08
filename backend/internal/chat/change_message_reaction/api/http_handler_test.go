package changemessagereactionapi

import (
	"context"
	"net/http/httptest"
	"strings"
	"testing"
	action "voice-platform/backend/internal/chat/change_message_reaction"
	identity "voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
)

type fakeChanger struct {
	input action.Input
	calls int
	err   error
}

func (f *fakeChanger) Set(_ context.Context, in action.Input) (action.Result, error) {
	f.calls++
	f.input = in
	return action.Result{}, f.err
}
func TestReactionMutationBindsPrincipalScopeAndExplicitMethodWithoutBody(t *testing.T) {
	for _, c := range []struct {
		method, body string
		direct       bool
		err          error
		status       int
	}{{"PUT", "", false, nil, 204}, {"DELETE", "", true, nil, 204}, {"PUT", "{}", false, nil, 400}, {"GET", "", false, nil, 405}, {"PUT", "", true, action.ErrUnavailable, 404}, {"PUT", "", false, action.ErrInvalidInput, 400}} {
		f := &fakeChanger{err: c.err}
		r := httptest.NewRequest(c.method, "/", strings.NewReader(c.body))
		r.SetPathValue("channelID", "22222222-2222-4222-8222-222222222222")
		r.SetPathValue("directMessageID", "33333333-3333-4333-8333-333333333333")
		r.SetPathValue("messageID", "44444444-4444-4444-8444-444444444444")
		r.SetPathValue("emoji", "👍")
		r = r.WithContext(sessionapi.WithPrincipal(r.Context(), identity.Principal{AccountID: "11111111-1111-4111-8111-111111111111", Role: "MEMBER"}))
		w := httptest.NewRecorder()
		NewHandler(f, c.direct).ServeHTTP(w, r)
		if w.Code != c.status || w.Header().Get("Cache-Control") != "no-store" {
			t.Fatal("unexpected status/cache")
		}
		if c.status == 204 && (f.input.Direct != c.direct || f.input.Present != (c.method == "PUT") || f.input.ActorID == "") {
			t.Fatal("principal/scope desired state lost")
		}
		if c.body != "" && f.calls != 0 {
			t.Fatal("body reached effect")
		}
	}
	f := &fakeChanger{}
	w := httptest.NewRecorder()
	NewHandler(f, false).ServeHTTP(w, httptest.NewRequest("PUT", "/", nil))
	if w.Code != 403 || f.calls != 0 {
		t.Fatal("anonymous effect accepted")
	}
}
