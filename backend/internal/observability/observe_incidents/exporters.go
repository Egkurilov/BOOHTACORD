package observeincidents

import (
	"context"
	sdkmetric "go.opentelemetry.io/otel/sdk/metric"
	"go.opentelemetry.io/otel/sdk/metric/metricdata"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	"time"
)

type TraceExporter struct{ sdktrace.SpanExporter }

func (e TraceExporter) ExportSpans(ctx context.Context, spans []sdktrace.ReadOnlySpan) error {
	started := time.Now()
	err := e.SpanExporter.ExportSpans(ctx, spans)
	Observe("trace_export", started, err)
	return err
}

type MetricExporter struct{ sdkmetric.Exporter }

func (e MetricExporter) Export(ctx context.Context, data *metricdata.ResourceMetrics) error {
	started := time.Now()
	err := e.Exporter.Export(ctx, data)
	Observe("metric_export", started, err)
	return err
}
