package observe_resources

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"
	"voice-platform/backend/internal/load/validate_target"
)

func TestRestoreWorksWhileResourcesUnavailableButRequiresNonce(t *testing.T) {
	restores := 0
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("X-Load-Nonce") != "private" {
			w.WriteHeader(403)
			return
		}
		if r.URL.Path == "/fault/restore" {
			restores++
			w.WriteHeader(204)
			return
		}
		w.WriteHeader(503)
	}))
	defer server.Close()
	g := Guard{Manifest: validate_target.Manifest{Guard: server.URL, Nonce: "private"}, Client: validate_target.Client()}
	if g.Fault(context.Background(), "sfu_outage") == nil {
		t.Fatal("new workload fault admitted during resource failure")
	}
	if err := g.Fault(context.Background(), "restore"); err != nil {
		t.Fatal(err)
	}
	g.Manifest.Nonce = "foreign"
	if g.Fault(context.Background(), "restore") == nil {
		t.Fatal("foreign recovery accepted")
	}
	if restores != 1 {
		t.Fatal(restores)
	}
}
