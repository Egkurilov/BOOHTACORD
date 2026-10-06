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

func TestNativeSDKExportsRenderedFlowToTempo(t *testing.T) {
	if os.Getenv("TRACE_QA_NATIVE") != "1" {
		t.Skip("explicit native Flutter engine runtime profile required")
	}
	collector, tempo := privateQA(t, "TRACE_QA_COLLECTOR_URL"), privateQA(t, "TRACE_QA_TEMPO_URL")
	binary := os.Getenv("TRACE_QA_FLUTTER_BIN")
	if binary == "" {
		t.Fatal("set installed pinned Flutter binary path")
	}
	principal := authenticatesession.Principal{AccountID: "11111111-1111-4111-8111-111111111111", SessionDigest: [32]byte{1}}
	binding := correlatesession.Attributes(principal.AccountID, principal.SessionDigest)[1].Value.AsString()
	relay := NewHandler(collector+"/v1/traces", "synthetic-QA-only", &http.Client{Timeout: 3 * time.Second, Transport: &http.Transport{Proxy: nil}})
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		relay.ServeHTTP(w, r.WithContext(sessionapi.WithPrincipal(r.Context(), principal)))
	}))
	defer server.Close()
	ctx, cancel := context.WithTimeout(context.Background(), 90*time.Second)
	defer cancel()
	args := []string{"test", "--no-pub", "test/features/telemetry/runtime_export_test.dart"}
	if runtime.GOOS == "windows" {
		args = append([]string{"/c", binary}, args...)
		binary = "cmd"
	}
	command := exec.CommandContext(ctx, binary, args...)
	command.Dir = filepath.Join("..", "..", "..", "..", "clients", "flutter")
	command.Env = append(os.Environ(), "TRACE_QA_RELAY_URL="+server.URL, "TRACE_QA_TEMPO_URL="+tempo, "TRACE_QA_SESSION="+binding)
	output, err := command.CombinedOutput()
	t.Log(string(output))
	if err != nil {
		t.Fatalf("native runtime: %v", err)
	}
}
