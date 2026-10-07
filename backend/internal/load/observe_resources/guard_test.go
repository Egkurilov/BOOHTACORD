package observe_resources

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
	"voice-platform/backend/internal/load/validate_target"
)

func TestGuardAttestationAndAutomaticStop(t *testing.T) {
	snapshot := Snapshot{Owner: "qa-client-0123456789abcdef", Dataset: "qa", Origin: "https://localhost:4810", Commit: "0123456789012345678901234567890123456789", At: time.Now(), CPUPercent: 1, RSSBytes: 1024, FreeBytes: 1 << 30, DBName: "qa", Accounts: 3}
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("X-Load-Nonce") != "secret" {
			w.WriteHeader(403)
			return
		}
		json.NewEncoder(w).Encode(snapshot)
	}))
	defer server.Close()
	m := validate_target.Manifest{Guard: server.URL, Nonce: "secret", Origin: snapshot.Origin, Owner: snapshot.Owner, Commit: snapshot.Commit, Dataset: "qa", Accounts: make([]validate_target.Account, 2)}
	g := Guard{Manifest: m, Client: validate_target.Client()}
	if _, err := g.Check(context.Background()); err != nil {
		t.Fatal(err)
	}
	for _, change := range []func(){func() { snapshot.Owner = "foreign" }, func() { snapshot.DBName = "production" }, func() { snapshot.Accounts = 4 }, func() { snapshot.At = time.Now().Add(-6 * time.Second) }, func() { snapshot.FreeBytes = 1 }, func() { snapshot.CPUPercent = 99 }} {
		original := snapshot
		change()
		if _, err := g.Check(context.Background()); err == nil {
			t.Fatal("unsafe guard accepted")
		}
		snapshot = original
	}
}
