package reportscreenapi

import (
	"context"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	"go.opentelemetry.io/otel/sdk/trace/tracetest"
	"net/http/httptest"
	"strings"
	"testing"
	auth "voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	httpmetrics "voice-platform/backend/internal/observability/http_metrics"
)

func TestProfileCheckReachesMediaSample(t *testing.T) {
	exporter := tracetest.NewInMemoryExporter()
	provider := sdktrace.NewTracerProvider(sdktrace.WithSyncer(exporter))
	old := otel.GetTracerProvider()
	otel.SetTracerProvider(provider)
	t.Cleanup(func() { otel.SetTracerProvider(old); _ = provider.Shutdown(context.Background()) })
	body := `{"platform":"desktop_web","direction":"sender","state":"playing","target_resolution":1080,"target_fps":60,"profile_check_status":"drift","profile_check_reason":"capture","profile_repair_attempts":0,"capture_width":2560,"capture_height":1440,"capture_fps":60}`
	request := httptest.NewRequest("POST", "/", strings.NewReader(body))
	request = request.WithContext(sessionapi.WithPrincipal(request.Context(), auth.Principal{AccountID: "verified-account"}))
	response := httptest.NewRecorder()
	NewSubmitHandler(httpmetrics.New()).ServeHTTP(response, request)
	if response.Code != 204 {
		t.Fatalf("status=%d", response.Code)
	}
	spans := exporter.GetSpans()
	if len(spans) != 1 {
		t.Fatalf("spans=%d", len(spans))
	}
	attrs := map[attribute.Key]attribute.Value{}
	for _, a := range spans[0].Attributes {
		attrs[a.Key] = a.Value
	}
	for key, want := range map[attribute.Key]string{"media.profile_check_status": "drift", "media.profile_check_reason": "capture"} {
		if attrs[key].AsString() != want {
			t.Fatalf("missing %s", key)
		}
	}
	for key, want := range map[attribute.Key]int64{"media.profile_repair_attempts": 0, "media.capture_width": 2560, "media.capture_height": 1440} {
		if got, ok := attrs[key]; !ok || got.AsInt64() != want {
			t.Fatalf("missing %s", key)
		}
	}
	if attrs["media.capture_fps"].AsFloat64() != 60 {
		t.Fatal("missing capture FPS")
	}
}
