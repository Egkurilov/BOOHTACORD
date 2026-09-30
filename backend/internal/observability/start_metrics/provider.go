package startmetrics

import (
	"context"
	"os"
	"time"

	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/exporters/otlp/otlpmetric/otlpmetrichttp"
	sdkmetric "go.opentelemetry.io/otel/sdk/metric"
	"go.opentelemetry.io/otel/sdk/resource"
)

// Start exports only explicitly recorded instruments; existing private Prometheus metrics remain intact.
func Start(ctx context.Context) (func(context.Context) error, error) {
	if os.Getenv("OTEL_EXPORTER_OTLP_ENDPOINT") == "" && os.Getenv("OTEL_EXPORTER_OTLP_METRICS_ENDPOINT") == "" {
		return func(context.Context) error { return nil }, nil
	}
	options := []otlpmetrichttp.Option{}
	if authorization := os.Getenv("OTEL_INGEST_AUTH"); authorization != "" {
		options = append(options, otlpmetrichttp.WithHeaders(map[string]string{"Authorization": authorization}))
	}
	exporter, err := otlpmetrichttp.New(ctx, options...)
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
	provider := sdkmetric.NewMeterProvider(
		sdkmetric.WithResource(service),
		sdkmetric.WithReader(sdkmetric.NewPeriodicReader(exporter, sdkmetric.WithInterval(15*time.Second))),
	)
	otel.SetMeterProvider(provider)
	return provider.Shutdown, nil
}
