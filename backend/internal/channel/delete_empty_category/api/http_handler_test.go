package deleteemptycategoryapi

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	deleteemptycategory "voice-platform/backend/internal/channel/delete_empty_category"
	auth "voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
)

func TestHandlerMapsDeleteOutcomes(t *testing.T) {
	for _, tc := range []struct {
		err  error
		code int
	}{{nil, 200}, {deleteemptycategory.ErrRevisionConflict, 409}} {
		d := &fakeDeleter{err: tc.err, result: deleteemptycategory.Result{ID: "category-1", Revision: 3}}
		r := httptest.NewRequest(http.MethodDelete, "/api/v1/admin/categories/category-1?expected_revision=2", nil)
		r.SetPathValue("categoryID", "category-1")
		r = r.WithContext(sessionapi.WithPrincipal(r.Context(), auth.Principal{AccountID: "admin-1"}))
		w := httptest.NewRecorder()
		NewHandler(d).ServeHTTP(w, r)
		if w.Code != tc.code {
			t.Fatalf("status=%d body=%s", w.Code, w.Body.String())
		}
	}
}
func TestHandlerRejectsMalformedRevision(t *testing.T) {
	r := httptest.NewRequest(http.MethodDelete, "/api/v1/admin/categories/x?expected_revision=no", nil)
	r = r.WithContext(sessionapi.WithPrincipal(r.Context(), auth.Principal{AccountID: "admin-1"}))
	w := httptest.NewRecorder()
	NewHandler(&fakeDeleter{}).ServeHTTP(w, r)
	if w.Code != 400 || !strings.Contains(w.Body.String(), "VALIDATION_FAILED") {
		t.Fatal(w.Code, w.Body.String())
	}
}

func TestNeutralHandlerReadsConfirmedBody(t *testing.T) {
	d := &fakeDeleter{result: deleteemptycategory.Result{ID: "category-1", Revision: 5}}
	r := httptest.NewRequest(http.MethodDelete, "/api/v1/categories/category-1", strings.NewReader(`{"client_request_id":"d38c4397-b019-45b4-a7b8-cecb7c8b7573","expected_revision":4,"confirm_delete":true}`))
	r.SetPathValue("categoryID", "category-1")
	r = r.WithContext(sessionapi.WithPrincipal(r.Context(), auth.Principal{AccountID: "member-1"}))
	w := httptest.NewRecorder()
	NewHandler(d).ServeHTTP(w, r)
	if w.Code != http.StatusOK || !strings.Contains(w.Body.String(), `"state":"DELETED"`) {
		t.Fatalf("response=%d %s", w.Code, w.Body.String())
	}
}

type fakeDeleter struct {
	err    error
	result deleteemptycategory.Result
}

func (d *fakeDeleter) Delete(_ context.Context, _ deleteemptycategory.Input) (deleteemptycategory.Result, error) {
	if d.err != nil {
		return deleteemptycategory.Result{}, d.err
	}
	return d.result, nil
}

var _ = errors.Is
