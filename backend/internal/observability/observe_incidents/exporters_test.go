package observeincidents

import (
	"context"
	"errors"
	dto "github.com/prometheus/client_model/go"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	"testing"
)

type failingTrace struct{}

func (failingTrace) ExportSpans(context.Context, []sdktrace.ReadOnlySpan) error {
	return errors.New("private-token")
}
func (failingTrace) Shutdown(context.Context) error { return nil }
func TestFailedTraceExportIsObservable(t *testing.T) {
	old := Default
	Default = New()
	defer func() { Default = old }()
	err := (TraceExporter{SpanExporter: failingTrace{}}).ExportSpans(context.Background(), nil)
	if err == nil || gaugeValue(Default.result.WithLabelValues("trace_export")) != 0 || gaugeValue(Default.total.WithLabelValues("trace_export", "failure")) != 1 {
		t.Fatal("failure lost")
	}
}

func gaugeValue(m interface{ Write(*dto.Metric) error }) float64 {
	v := &dto.Metric{}
	_ = m.Write(v)
	if v.Gauge != nil {
		return v.Gauge.GetValue()
	}
	return v.Counter.GetValue()
}
