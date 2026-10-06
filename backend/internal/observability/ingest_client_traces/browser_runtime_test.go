//go:build tracing_runtime

package ingestclienttraces

import (
	"context"
	"net/http"
	"net/http/httptest"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"testing"
	"time"
	authenticatesession "voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	correlatesession "voice-platform/backend/internal/observability/correlate_session"
)

// Real browser SDK and Vue components feed the production relay and real Tempo.
// Business API responses are synthetic; this does not prove DB or physical media.
func TestBrowserComponentsExportThroughRelayToTempo(t *testing.T) {
	if os.Getenv("TRACE_QA_BROWSER") != "1" {
		t.Skip("explicit browser runtime profile required")
	}
	collector, tempo := privateQA(t, "TRACE_QA_COLLECTOR_URL"), privateQA(t, "TRACE_QA_TEMPO_URL")
	principal := authenticatesession.Principal{AccountID: "11111111-1111-4111-8111-111111111111", SessionDigest: [32]byte{1}}
	binding := correlatesession.Attributes(principal.AccountID, principal.SessionDigest)[1].Value.AsString()
	relay := NewHandler(collector+"/v1/traces", "synthetic-QA-only", &http.Client{Timeout: 3 * time.Second, Transport: &http.Transport{Proxy: nil}})
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		result := httptest.NewRecorder()
		relay.ServeHTTP(result, r.WithContext(sessionapi.WithPrincipal(r.Context(), principal)))
		t.Logf("browser relay status=%d accepted=%s rejected=%s", result.Code, result.Header().Get("X-Telemetry-Accepted"), result.Header().Get("X-Telemetry-Rejected"))
		for key, values := range result.Header() {
			w.Header()[key] = values
		}
		w.WriteHeader(result.Code)
		_, _ = w.Write(result.Body.Bytes())
	}))
	defer server.Close()
	ctx, cancel := context.WithTimeout(context.Background(), 180*time.Second)
	defer cancel()
	args := []string{"playwright", "test", "-c", "tests/tracing_flow/playwright.config.ts"}
	binary := "npx"
	if runtime.GOOS == "windows" {
		binary = "cmd"
		args = append([]string{"/c", "npx"}, args...)
	}
	command := exec.CommandContext(ctx, binary, args...)
	command.Dir = filepath.Join("..", "..", "..", "..", "clients", "web")
	command.Env = append(os.Environ(), "TRACE_QA_RELAY_URL="+server.URL, "TRACE_QA_TEMPO_URL="+tempo, "TRACE_QA_SESSION="+binding)
	output, err := command.CombinedOutput()
	t.Log(string(output))
	if err != nil {
		t.Fatalf("browser runtime: %v", err)
	}
}
