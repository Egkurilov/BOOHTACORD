package reportscreenapi

import (
	"context"
	"testing"

	"go.opentelemetry.io/otel"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	"go.opentelemetry.io/otel/sdk/trace/tracetest"
	auth "voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	httpmetrics "voice-platform/backend/internal/observability/http_metrics"
)

func TestPrivateHistoryKeepsReportedDropsWithoutInventingMissingCounts(t *testing.T) {
	exporter := tracetest.NewInMemoryExporter()
	provider := sdktrace.NewTracerProvider(sdktrace.WithSyncer(exporter))
	old := otel.GetTracerProvider()
	otel.SetTracerProvider(provider)
	t.Cleanup(func() { otel.SetTracerProvider(old); _ = provider.Shutdown(context.Background()) })
	ctx := sessionapi.WithPrincipal(context.Background(), auth.Principal{AccountID: "synthetic-verified"})
	dropped, lost := int64(3), int64(4)
	report := httpmetrics.ClientScreenReport{Platform: "desktop_web", Direction: "receiver", State: "playing", DroppedFrames: &dropped, PacketsLost: &lost}
	recordMediaSample(ctx, report)
	report.DroppedFrames, report.PacketsLost = nil, nil
	recordMediaSample(ctx, report)
	spans := exporter.GetSpans()
	if len(spans) != 2 {
		t.Fatal(len(spans))
	}
	for index, span := range spans {
		found := 0
		for _, a := range span.Attributes {
			switch string(a.Key) {
			case "media.dropped_frames":
				if a.Value.AsInt64() != dropped {
					t.Fatal("wrong drop counter")
				}
				found++
			case "media.packets_lost":
				if a.Value.AsInt64() != lost {
					t.Fatal("wrong loss counter")
				}
				found++
			}
		}
		if (index == 0 && found != 2) || (index == 1 && found != 0) {
			t.Fatalf("sample%d invented or omitted counts", index)
		}
	}
}
