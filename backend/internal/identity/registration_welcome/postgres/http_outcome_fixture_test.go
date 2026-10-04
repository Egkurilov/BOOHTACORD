package welcomepostgres

import (
	"context"
	"encoding/json"
	"fmt"
	"go.opentelemetry.io/otel/metric/noop"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	"go.opentelemetry.io/otel/sdk/trace/tracetest"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	registeruser "voice-platform/backend/internal/identity/register_user"
	registerapi "voice-platform/backend/internal/identity/register_user/api"
	guildlifecycle "voice-platform/backend/internal/observability/guild_lifecycle"
	httpmetrics "voice-platform/backend/internal/observability/http_metrics"
	tracehttp "voice-platform/backend/internal/observability/trace_http"
)

func welcomeHTTP(t *testing.T, repo Repository) (int, string, []sdktrace.ReadOnlySpan, string) {
	t.Helper()
	recorder := tracetest.NewSpanRecorder()
	provider := sdktrace.NewTracerProvider(sdktrace.WithSpanProcessor(recorder))
	t.Cleanup(func() { _ = provider.Shutdown(context.Background()) })
	metrics := httpmetrics.New()
	repo.Observer = guildlifecycle.New(provider.Tracer("test"), noop.NewMeterProvider().Meter("test"), metrics)
	mux := http.NewServeMux()
	mux.Handle("POST /api/v1/auth/register", registerapi.NewHandler(registeruser.New(repo)))
	response := httptest.NewRecorder()
	request := httptest.NewRequest("POST", "/api/v1/auth/register", strings.NewReader(`{"login":"NewMember","password":"PRIVATE_PASSWORD_VALID"}`))
	tracehttp.Middleware(provider.Tracer("test"), mux, mux).ServeHTTP(response, request)
	var body struct {
		ID string `json:"id"`
	}
	if err := json.Unmarshal(response.Body.Bytes(), &body); err != nil {
		t.Fatal("invalid response JSON")
	}
	metricResponse := httptest.NewRecorder()
	metrics.Handler().ServeHTTP(metricResponse, httptest.NewRequest("GET", "/metrics", nil))
	return response.Code, body.ID, recorder.Ended(), metricResponse.Body.String()
}

func welcomeAttributes(span sdktrace.ReadOnlySpan) map[string]any {
	attrs := map[string]any{}
	for _, attr := range span.Attributes() {
		attrs[string(attr.Key)] = attr.Value.AsInterface()
	}
	return attrs
}

func assertWelcomeSignalsPrivate(t *testing.T, spans []sdktrace.ReadOnlySpan, metrics, account, channel string) {
	t.Helper()
	for _, span := range spans {
		if welcomeAttributes(span)["session.id"] != nil {
			t.Fatal("session forged before login")
		}
		text := fmt.Sprint(span.Attributes(), span.Events(), span.Status())
		if strings.Contains(text, "PRIVATE_PASSWORD_VALID") || strings.Contains(text, "PRIVATE_DRIVER_SQL") {
			t.Fatal("sensitive signal")
		}
	}
	for _, value := range []string{"NewMember", channel, "user.id", "channel.id", "message.id", "PRIVATE_"} {
		if strings.Contains(metrics, value) {
			t.Fatal("high-cardinality or sensitive metric")
		}
	}
	if account != "" && strings.Contains(metrics, account) {
		t.Fatal("account ID metric label")
	}
}
