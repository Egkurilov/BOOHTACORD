package ingestclienttraces

import (
	"bytes"
	"google.golang.org/protobuf/proto"
	"net/http"
	"net/http/httptest"
	"os"
	"testing"
	"time"
	authenticatesession "voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	correlatesession "voice-platform/backend/internal/observability/correlate_session"
)

func TestActualCollectorOutageReturnsBoundedUnavailable(t *testing.T) {
	if os.Getenv("TRACE_QA_EXPECT_COLLECTOR_OUTAGE") != "1" {
		t.Skip("explicit isolated Collector outage profile required")
	}
	collector := privateQA(t, "TRACE_QA_COLLECTOR_URL")
	client := &http.Client{Timeout: 2 * time.Second, Transport: &http.Transport{Proxy: nil}}
	if response, err := client.Get(collector + "/v1/traces"); err == nil {
		response.Body.Close()
		t.Fatal("expected actual stopped Collector, not a simulated response")
	}
	principal := authenticatesession.Principal{AccountID: "11111111-1111-4111-8111-111111111111", SessionDigest: [32]byte{1}}
	binding := correlatesession.Attributes(principal.AccountID, principal.SessionDigest)[1].Value.AsString()
	span := flowSpan()
	for _, attr := range span.Attributes {
		if attr.Key == "session.id" {
			attr.Value = flowAttr("session.id", binding).Value
		}
	}
	body, _ := proto.Marshal(flowBatch(span))
	request := httptest.NewRequest(http.MethodPost, "/api/v1/telemetry/traces", bytes.NewReader(body))
	request = request.WithContext(sessionapi.WithPrincipal(request.Context(), principal))
	request.Header.Set("Content-Type", "application/x-protobuf")
	request.Header.Set("X-Client-Platform", "web")
	request.Header.Set("X-Telemetry-Session", binding)
	response := httptest.NewRecorder()
	started := time.Now()
	NewHandler(collector+"/v1/traces", "synthetic-QA-only", client).ServeHTTP(response, request)
	if response.Code != http.StatusServiceUnavailable || time.Since(started) > 4*time.Second {
		t.Fatalf("outage status=%d duration=%s", response.Code, time.Since(started))
	}
	if response.Header().Get("X-Telemetry-Accepted") != "" {
		t.Fatal("unavailable export reported acceptance")
	}
	t.Logf("actual stopped Collector: relay status=503 duration_ms=%d; no accepted receipt", time.Since(started).Milliseconds())
}
