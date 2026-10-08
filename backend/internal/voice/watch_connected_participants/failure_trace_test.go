package watchconnectedparticipants

import (
	"context"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	"go.opentelemetry.io/otel/sdk/trace/tracetest"
	"net/http/httptest"
	"strings"
	"testing"
	roster "voice-platform/backend/internal/voice/list_connected_participants"
)

func TestRefreshTraceUsesBoundedStageAndNoPrivateDependencyText(t *testing.T) {
	spans := tracetest.NewSpanRecorder()
	provider := sdktrace.NewTracerProvider(sdktrace.WithSpanProcessor(spans))
	defer provider.Shutdown(context.Background())
	ctx, span := provider.Tracer("roster-test").Start(context.Background(), "request")
	writer := httptest.NewRecorder()
	if refreshRosterSnapshot(ctx, errorLister{}, "viewer", func(roster.Result) bool { return true }, writer, writer, nil) {
		t.Fatal("unavailable dependency became success")
	}
	span.End()
	events := spans.Ended()[0].Events()
	if len(events) != 1 || events[0].Name != "voice_roster.failure" {
		t.Fatalf("failure events=%v", events)
	}
	for _, attribute := range events[0].Attributes {
		value := attribute.Value.AsString()
		if strings.Contains(value, "account") || strings.Contains(value, "room-456") || value != "visibility_initial" {
			t.Fatalf("unbounded failure event value=%q", value)
		}
	}
}
