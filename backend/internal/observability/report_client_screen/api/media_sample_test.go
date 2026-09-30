package reportscreenapi

import (
	"context"
	"crypto/sha256"
	"net/http/httptest"
	"strings"
	"testing"

	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	"go.opentelemetry.io/otel/sdk/trace/tracetest"
	auth "voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	correlation "voice-platform/backend/internal/observability/correlate_session"
	httpmetrics "voice-platform/backend/internal/observability/http_metrics"
)

func TestMediaSampleHasVerifiedIdentityAndMeasuredValues(t *testing.T) {
	exporter := tracetest.NewInMemoryExporter()
	provider := sdktrace.NewTracerProvider(sdktrace.WithSyncer(exporter))
	old := otel.GetTracerProvider()
	otel.SetTracerProvider(provider)
	t.Cleanup(func() { otel.SetTracerProvider(old); _ = provider.Shutdown(context.Background()) })
	principal := auth.Principal{AccountID: "verified-account", DisplayName: "Аня [QA]", SessionDigest: sha256.Sum256([]byte("secret"))}
	body := `{"platform":"ios_native","direction":"sender","state":"playing","rtt_ms":42,"bitrate_kbps":7500,"encoded_fps":55,"packet_loss_percent":0,"packet_loss_window_ms":10000,"target_resolution":1440,"target_fps":60,"connection_quality":"GOOD","sample_age_ms":200}`
	request := httptest.NewRequest("POST", "/", strings.NewReader(body))
	request.Header.Set("X-User-ID", "forged")
	request.Header.Set("X-User-Name", "forged-name")
	request = request.WithContext(sessionapi.WithPrincipal(request.Context(), principal))
	response := httptest.NewRecorder()
	NewSubmitHandler(httpmetrics.New()).ServeHTTP(response, request)
	if response.Code != 204 {
		t.Fatalf("status=%d", response.Code)
	}
	spans := exporter.GetSpans()
	if len(spans) != 1 || spans[0].Name != "media.sample" {
		t.Fatalf("spans=%v", spans)
	}
	attrs := map[attribute.Key]attribute.Value{}
	for _, attr := range spans[0].Attributes {
		attrs[attr.Key] = attr.Value
	}
	for _, expected := range correlation.NamedAttributes(principal.AccountID, principal.SessionDigest, principal.DisplayName) {
		if attrs[expected.Key] != expected.Value {
			t.Fatalf("identity mismatch: %s", expected.Key)
		}
	}
	for key, want := range map[attribute.Key]float64{"media.rtt_ms": 42, "media.bitrate_kbps": 7500, "media.encoded_fps": 55, "media.packet_loss_percent": 0, "media.packet_loss_window_ms": 10000, "media.target_resolution": 1440, "media.target_fps": 60} {
		if value, ok := attrs[key]; !ok || value.AsFloat64() != want {
			t.Fatalf("%s missing or wrong", key)
		}
	}
	if _, present := attrs["media.decoded_fps"]; present {
		t.Fatal("invented missing measurement")
	}
}

func TestInvalidMediaSamplesAreRejectedBeforeRecording(t *testing.T) {
	for _, extra := range []string{
		`"packet_loss_percent":101,"packet_loss_window_ms":10000`,
		`"packet_loss_percent":0`, `"packet_loss_window_ms":10000`,
		`"packet_loss_percent":1,"packet_loss_window_ms":600000`,
		`"target_resolution":9000`, `"target_fps":999`,
		`"connection_quality":"username"`, `"adaptation_reason":"secret"`,
		`"sample_age_ms":15001`, `"user_id":"forged"`,
	} {
		recorder := httpmetrics.New()
		body := `{"platform":"desktop_web","direction":"sender","state":"playing",` + extra + `}`
		response := httptest.NewRecorder()
		NewSubmitHandler(recorder).ServeHTTP(response, httptest.NewRequest("POST", "/", strings.NewReader(body)))
		if response.Code != 400 || len(recorder.ClientScreenSnapshot()) != 0 {
			t.Fatalf("accepted %s", extra)
		}
	}
}

func TestVoiceConnectionReportDoesNotPolluteScreenSnapshot(t *testing.T) {
	recorder := httpmetrics.New()
	response := httptest.NewRecorder()
	NewSubmitHandler(recorder).ServeHTTP(response, httptest.NewRequest("POST", "/", strings.NewReader(`{"platform":"ios_native","direction":"connection","state":"playing","rtt_ms":12,"connection_quality":"GOOD"}`)))
	if response.Code != 204 || len(recorder.ClientScreenSnapshot()) != 0 {
		t.Fatalf("status=%d", response.Code)
	}
}

func TestUnauthenticatedMediaSampleCreatesNoTrace(t *testing.T) {
	exporter := tracetest.NewInMemoryExporter()
	provider := sdktrace.NewTracerProvider(sdktrace.WithSyncer(exporter))
	old := otel.GetTracerProvider()
	otel.SetTracerProvider(provider)
	t.Cleanup(func() { otel.SetTracerProvider(old); _ = provider.Shutdown(context.Background()) })

	report := httpmetrics.ClientScreenReport{Platform: "desktop_web", Direction: "sender", State: "playing"}
	recordMediaSample(context.Background(), report)
	if spans := exporter.GetSpans(); len(spans) != 0 {
		t.Fatalf("unauthenticated media sample created %d trace spans", len(spans))
	}
}
