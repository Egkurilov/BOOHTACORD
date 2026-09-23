package listmembersapi

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	"voice-platform/backend/internal/identity/list_members"
)

func TestListRequiresSessionAndSerializesSafePage(t *testing.T) {
	reader := &fakeReader{result: listmembers.Result{Members: []listmembers.Member{{ID: "00000000-0000-4000-8000-000000000001", Login: "member", DisplayName: "Member", Role: "MEMBER", AvatarURL: "/api/v1/members/00000000-0000-4000-8000-000000000001/avatar"}, {ID: "00000000-0000-4000-8000-000000000002", Login: "owner", DisplayName: "Owner", Role: "ADMINISTRATOR"}}, NextCursor: "00000000-0000-4000-8000-000000000002"}}
	handler := NewHandler(reader)
	request := httptest.NewRequest(http.MethodGet, "/api/v1/members?limit=2", nil)
	request = request.WithContext(sessionapi.WithPrincipal(request.Context(), authenticatesession.Principal{AccountID: "viewer"}))
	recorder := httptest.NewRecorder()
	handler.ServeHTTP(recorder, request)
	if recorder.Code != http.StatusOK || !strings.Contains(recorder.Body.String(), `"next_cursor"`) || strings.Contains(recorder.Body.String(), "password_hash") || strings.Contains(recorder.Body.String(), "blocked_at") {
		t.Fatalf("status=%d body=%q", recorder.Code, recorder.Body.String())
	}
	if reader.input.Limit != 2 {
		t.Fatalf("input=%#v", reader.input)
	}
	unauthorized := httptest.NewRecorder()
	handler.ServeHTTP(unauthorized, httptest.NewRequest(http.MethodGet, "/api/v1/members", nil))
	if unauthorized.Code != http.StatusUnauthorized {
		t.Fatalf("unauthorized status=%d", unauthorized.Code)
	}
}

func TestDetailPassesOnlyRequestedMemberID(t *testing.T) {
	reader := &fakeReader{member: listmembers.Member{ID: "00000000-0000-4000-8000-000000000001", DisplayName: "Member", Role: "MEMBER"}}
	handler := NewDetailHandler(reader)
	request := httptest.NewRequest(http.MethodGet, "/api/v1/members/member", nil)
	request.SetPathValue("userID", reader.member.ID)
	request = request.WithContext(sessionapi.WithPrincipal(request.Context(), authenticatesession.Principal{AccountID: "viewer"}))
	recorder := httptest.NewRecorder()
	handler.ServeHTTP(recorder, request)
	if recorder.Code != http.StatusOK || reader.memberID != reader.member.ID {
		t.Fatalf("status=%d ID=%q", recorder.Code, reader.memberID)
	}
}

type fakeReader struct {
	input    listmembers.Input
	result   listmembers.Result
	member   listmembers.Member
	memberID string
}

func (reader *fakeReader) List(_ context.Context, input listmembers.Input) (listmembers.Result, error) {
	reader.input = input
	return reader.result, nil
}
func (reader *fakeReader) Get(_ context.Context, id string) (listmembers.Member, error) {
	reader.memberID = id
	return reader.member, nil
}
