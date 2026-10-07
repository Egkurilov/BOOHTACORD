package starttracing

import (
	"context"
	"os"
	"time"
	incident "voice-platform/backend/internal/observability/observe_incidents"

	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracehttp"
	"go.opentelemetry.io/otel/propagation"
	"go.opentelemetry.io/otel/sdk/resource"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
)

// Start enables explicit spans when an OTLP endpoint is configured.
func Start(ctx context.Context) (func(context.Context) error, error) {
	configured := os.Getenv("OTEL_EXPORTER_OTLP_ENDPOINT") != "" || os.Getenv("OTEL_EXPORTER_OTLP_TRACES_ENDPOINT") != ""
	incident.Default.SetEnabled("trace_export", configured)
	if !configured {
		return func(context.Context) error { return nil }, nil
	}
	options := []otlptracehttp.Option{}
	if authorization := os.Getenv("OTEL_INGEST_AUTH"); authorization != "" {
		options = append(options, otlptracehttp.WithHeaders(map[string]string{"Authorization": authorization}))
	}
	exporter, err := otlptracehttp.New(ctx, options...)
	if err != nil {
		return nil, err
	}
	service, err := resource.New(ctx, resource.WithAttributes(
		attribute.String("service.name", "boohtacord-api"),
		attribute.String("service.version", os.Getenv("APP_VERSION")),
	))
	if err != nil {
		return nil, err
	}
	provider := sdktrace.NewTracerProvider(
		sdktrace.WithResource(service),
		sdktrace.WithSampler(configuredSampler()),
		sdktrace.WithBatcher(incident.TraceExporter{SpanExporter: exporter},
			sdktrace.WithMaxQueueSize(128),
			sdktrace.WithMaxExportBatchSize(16),
			sdktrace.WithBatchTimeout(5*time.Second),
			sdktrace.WithExportTimeout(3*time.Second),
		),
	)
	otel.SetTracerProvider(provider)
	otel.SetTextMapPropagator(propagation.TraceContext{})
	return provider.Shutdown, nil
}
