package clientupdates

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

type fixedProvider struct {
	policy Policy
	ok     bool
}

func (p fixedProvider) Policy(Selector) (Policy, bool) { return p.policy, p.ok }

func TestHandlerServesPublicPolicyWithSecurityHeaders(t *testing.T) {
	catalog, _ := Parse(strings.NewReader(validCatalog), nil)
	policy, _ := catalog.Select(Selector{Platform: "web", Distribution: "browser", Channel: "stable", Arch: "any"})
	recorder := httptest.NewRecorder()
	request := httptest.NewRequest(http.MethodGet, "/api/v1/client-updates?platform=web&distribution=browser&channel=stable&arch=any", nil)
	Handler(fixedProvider{policy: policy, ok: true}).ServeHTTP(recorder, request)
	if recorder.Code != http.StatusOK {
		t.Fatalf("status %d: %s", recorder.Code, recorder.Body)
	}
	if recorder.Header().Get("Cache-Control") != "no-store" || recorder.Header().Get("X-Content-Type-Options") != "nosniff" {
		t.Fatal("missing response security headers")
	}
}

func TestHandlerReportsColdStartUnavailable(t *testing.T) {
	recorder := httptest.NewRecorder()
	Handler(fixedProvider{}).ServeHTTP(recorder, httptest.NewRequest(http.MethodGet, "/api/v1/client-updates?platform=web&distribution=browser&channel=stable&arch=any", nil))
	if recorder.Code != http.StatusServiceUnavailable {
		t.Fatalf("status %d", recorder.Code)
	}
}
