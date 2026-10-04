package welcomepostgres

import (
	"bytes"
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
	tracehttp "voice-platform/backend/internal/observability/trace_http"
)

func TestRegistrationHTTPSpanHasChildAndServerIdentityWithoutSession(t *testing.T) {
	recorder := tracetest.NewSpanRecorder()
	provider := sdktrace.NewTracerProvider(sdktrace.WithSpanProcessor(recorder))
	defer provider.Shutdown(t.Context())
	tracer := provider.Tracer("test")
	channel := "11111111-1111-4111-8111-111111111111"
	repo := Repository{Database: fakeDatabase{&fakeTransaction{channel: &channel, active: true}}, Events: &publisher{}, Observer: guildlifecycle.New(tracer, noop.NewMeterProvider().Meter("test"), nil), Random: bytes.NewReader(make([]byte, 32))}
	mux := http.NewServeMux()
	mux.Handle("POST /api/v1/auth/register", registerapi.NewHandler(registeruser.New(repo)))
	response := httptest.NewRecorder()
	tracehttp.Middleware(tracer, mux, mux).ServeHTTP(response, httptest.NewRequest("POST", "/api/v1/auth/register", strings.NewReader(`{"login":"NewMember","password":"correct horse battery staple"}`)))
	spans := recorder.Ended()
	if response.Code != 201 || len(spans) != 2 {
		t.Fatal("registration did not produce server and welcome spans")
	}
	child, root := spans[0], spans[1]
	if child.Parent().SpanID() != root.SpanContext().SpanID() || child.SpanContext().TraceID() != root.SpanContext().TraceID() {
		t.Fatal("welcome detached from HTTP trace")
	}
	for _, span := range spans {
		attrs := map[string]any{}
		for _, a := range span.Attributes() {
			attrs[string(a.Key)] = a.Value.AsInterface()
		}
		if attrs["user.id"] == nil || attrs["user.name"] != "NewMember" || attrs["session.id"] != nil {
			t.Fatal("missing identity or synthetic session")
		}
		for _, value := range attrs {
			if value == "correct horse battery staple" {
				t.Fatal("password exported")
			}
		}
	}
}
