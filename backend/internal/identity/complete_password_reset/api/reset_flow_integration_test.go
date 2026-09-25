package resetapi_test

import (
	"encoding/json"
	"net/http"
	"net/url"
	"testing"
)

func TestIssuedResetLinkCompletesOnceAndInvalidatesOldLoginAndSession(t *testing.T) {
	fixture := newResetFlowFixture(t)
	client := fixture.server.Client()
	createURL := fixture.server.URL + "/api/v1/admin/password-reset-links"
	if response := postResetJSON(t, client, createURL, map[string]string{"account_id": fixture.memberID}, fixture.memberCookie); response.StatusCode != http.StatusForbidden {
		t.Fatalf("member reset-link creation status = %d", response.StatusCode)
	}
	issued := postResetJSON(t, client, createURL, map[string]string{"account_id": fixture.memberID}, fixture.adminCookie)
	if issued.StatusCode != http.StatusCreated {
		t.Fatalf("admin reset-link creation status = %d", issued.StatusCode)
	}
	var link struct {
		URL string `json:"url"`
	}
	if err := json.NewDecoder(issued.Body).Decode(&link); err != nil {
		t.Fatal(err)
	}
	parsed, err := url.Parse(link.URL)
	if err != nil || parsed.Path != "/reset-password" || parsed.RawQuery != "" {
		t.Fatalf("reset link shape invalid: %v", err)
	}
	fragment, err := url.ParseQuery(parsed.Fragment)
	if err != nil || fragment.Get("token") == "" {
		t.Fatalf("reset fragment invalid: %v", err)
	}
	token := fragment.Get("token")
	completeURL := fixture.server.URL + "/api/v1/auth/password-reset/complete"
	if response := postResetJSON(t, client, completeURL, map[string]string{"token": token, "password": newResetPassword}, nil); response.StatusCode != http.StatusNoContent {
		t.Fatalf("reset completion status = %d", response.StatusCode)
	}
	if response := postResetJSON(t, client, completeURL, map[string]string{"token": token, "password": newResetPassword}, nil); response.StatusCode != http.StatusBadRequest {
		t.Fatalf("reused reset-link status = %d", response.StatusCode)
	}
	request, err := http.NewRequest(http.MethodGet, fixture.server.URL+"/api/v1/auth/session", nil)
	if err != nil {
		t.Fatal(err)
	}
	request.AddCookie(fixture.memberCookie)
	response, err := client.Do(request)
	if err != nil {
		t.Fatal(err)
	}
	_ = response.Body.Close()
	if response.StatusCode != http.StatusUnauthorized {
		t.Fatalf("old session status = %d", response.StatusCode)
	}
	loginURL := fixture.server.URL + "/api/v1/auth/login"
	for _, attempt := range []struct {
		password string
		want     int
	}{{oldResetPassword, http.StatusUnauthorized}, {newResetPassword, http.StatusNoContent}} {
		response := postResetJSON(t, client, loginURL, map[string]string{"login": "qa02member", "password": attempt.password}, nil)
		if response.StatusCode != attempt.want {
			t.Fatalf("login after reset status = %d, want %d", response.StatusCode, attempt.want)
		}
	}
}
