package watchconnectedparticipants

import (
	"context"
	"net/http/httptest"
	"testing"

	"go.opentelemetry.io/otel"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	"go.opentelemetry.io/otel/sdk/trace/tracetest"
	requestid "voice-platform/backend/internal/security/request_id"
)

func TestActualInitialHandlerCreatesBoundedRequestCorrelatedSpan(t *testing.T) {
	spans := tracetest.NewSpanRecorder()
	provider := sdktrace.NewTracerProvider(sdktrace.WithSpanProcessor(spans))
	old := otel.GetTracerProvider()
	otel.SetTracerProvider(provider)
	t.Cleanup(func() { otel.SetTracerProvider(old); _ = provider.Shutdown(context.Background()) })
	writer := httptest.NewRecorder()
	request := testSessionRequest(httptest.NewRequest("GET", "/api/v1/voice/rosters/events", nil))
	requestid.Middleware(NewHandler(errorLister{}, NewNotifier(), nil)).ServeHTTP(writer, request)
	ended := spans.Ended()
	if len(ended) != 1 || ended[0].Name() != "voice.roster.initial" {
		t.Fatal("actual initial request has no ended diagnostic span")
	}
	requestID := writer.Header().Get("X-Request-ID")
	matched := false
	for _, attr := range ended[0].Attributes() {
		if string(attr.Key) == "request_id" && attr.Value.AsString() == requestID && requestID != "" {
			matched = true
		}
	}
	if !matched {
		t.Fatal("span cannot correlate the actual response request ID")
	}
	events := ended[0].Events()
	if len(events) != 1 || events[0].Name != "voice_roster.failure" {
		t.Fatal("initial dependency failure not retained in bounded span")
	}
	if len(events[0].Attributes) != 1 || events[0].Attributes[0].Value.AsString() != "visibility_initial" {
		t.Fatal("initial failure leaked dependency text or lost bounded stage")
	}
}
