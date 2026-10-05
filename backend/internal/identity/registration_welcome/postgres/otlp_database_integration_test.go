package welcomepostgres

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"go.opentelemetry.io/otel/metric/noop"
	tracepb "go.opentelemetry.io/proto/otlp/trace/v1"
	registeruser "voice-platform/backend/internal/identity/register_user"
	registerapi "voice-platform/backend/internal/identity/register_user/api"
	guildlifecycle "voice-platform/backend/internal/observability/guild_lifecycle"
	httpmetrics "voice-platform/backend/internal/observability/http_metrics"
	tracehttp "voice-platform/backend/internal/observability/trace_http"
	guildfixture "voice-platform/backend/internal/testsupport/guild_lifecycle"
)

func TestRealRegistrationDatabaseAndOTLPExport(t *testing.T) {
	f := guildfixture.New(t)
	if _, err := f.Pool.Exec(f.Context, `UPDATE guild_settings SET welcome_channel_id=$1 WHERE singleton=TRUE`, f.Channel); err != nil {
		t.Fatal(err)
	}
	provider, received := newOTLPRecorder(t)
	metrics := httpmetrics.New()
	repo := Repository{Database: f.Pool, Events: &publisher{}, Random: bytes.NewReader(make([]byte, 32)), Observer: guildlifecycle.New(provider.Tracer("integration"), noop.NewMeterProvider().Meter("test"), metrics)}
	mux := http.NewServeMux()
	mux.Handle("POST /api/v1/auth/register", registerapi.NewHandler(registeruser.New(repo)))
	server := httptest.NewServer(tracehttp.Middleware(provider.Tracer("integration"), mux, mux))
	defer server.Close()
	response, err := http.Post(server.URL+"/api/v1/auth/register", "application/json", strings.NewReader(`{"login":"OTLPFixture","password":"PRIVATE_PASSWORD_VALID"}`))
	if err != nil {
		t.Fatal(err)
	}
	defer response.Body.Close()
	var account struct {
		ID string `json:"id"`
	}
	if err = json.NewDecoder(response.Body).Decode(&account); err != nil {
		t.Fatal(err)
	}
	if response.StatusCode != 201 || account.ID == "" {
		t.Fatal("registration failed")
	}
	var messageID, body string
	if err = f.Pool.QueryRow(f.Context, `SELECT id::text,body FROM messages WHERE author_id=$1 AND kind='SYSTEM_WELCOME'`, account.ID).Scan(&messageID, &body); err != nil {
		t.Fatal(err)
	}
	if err = provider.ForceFlush(f.Context); err != nil {
		t.Fatal(err)
	}
	var spans []*tracepb.Span
	for len(received) > 0 {
		batch := <-received
		for _, resource := range batch.ResourceSpans {
			for _, scope := range resource.ScopeSpans {
				spans = append(spans, scope.Spans...)
			}
		}
	}
	if len(spans) != 2 {
		t.Fatalf("expected HTTP root and welcome child, got %d", len(spans))
	}
	child, root := spans[0], spans[1]
	if child.Name != "registration.welcome" || !bytes.Equal(child.ParentSpanId, root.SpanId) || !bytes.Equal(child.TraceId, root.TraceId) {
		t.Fatal("OTLP parent correlation lost")
	}
	for _, span := range spans {
		attrs := otlpAttributes(span)
		if attrs["user.id"] != account.ID || attrs["session.id"] != "" {
			t.Fatal("server account correlation mismatch")
		}
		wire := span.String()
		if strings.Contains(wire, body) || strings.Contains(wire, "PRIVATE_PASSWORD_VALID") {
			t.Fatal("message content or password exported")
		}
	}
	attrs := otlpAttributes(child)
	if attrs["message.id"] != messageID || attrs["channel.id"] != f.Channel || attrs["welcome.outcome"] != "published" {
		t.Fatal("welcome receipt not correlated")
	}
	metricResponse := httptest.NewRecorder()
	metrics.Handler().ServeHTTP(metricResponse, httptest.NewRequest("GET", "/metrics", nil))
	for _, line := range strings.Split(metricResponse.Body.String(), "\n") {
		if strings.HasPrefix(line, "voice_platform_registration_welcome_total{") && line != `voice_platform_registration_welcome_total{outcome="published"} 1` {
			t.Fatal("metric cardinality exceeded")
		}
	}
	t.Logf("isolated OTLP trace=%x; committed welcome correlated; no message/password in exported signals", child.TraceId)
}
