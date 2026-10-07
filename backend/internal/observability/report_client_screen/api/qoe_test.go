package reportscreenapi

import (
	"context"
	"net/http/httptest"
	"strings"
	"testing"

	"go.opentelemetry.io/otel"
	sdkmetric "go.opentelemetry.io/otel/sdk/metric"
	"go.opentelemetry.io/otel/sdk/metric/metricdata"
	httpmetrics "voice-platform/backend/internal/observability/http_metrics"
)

func TestAcceptedReportReachesOTELAndRejectedReportDoesNot(t *testing.T) {
	reader := sdkmetric.NewManualReader()
	provider := sdkmetric.NewMeterProvider(sdkmetric.WithReader(reader))
	old := otel.GetMeterProvider()
	otel.SetMeterProvider(provider)
	t.Cleanup(func() { otel.SetMeterProvider(old); _ = provider.Shutdown(context.Background()) })
	handler := NewSubmitHandler(httpmetrics.New())
	for _, test := range []struct {
		body   string
		status int
	}{
		{`{"platform":"desktop_web","direction":"receiver","state":"playing","rtt_ms":42,"sample_age_ms":100}`, 204},
		{`{"platform":"desktop_web","direction":"receiver","state":"playing","rtt_ms":-1}`, 400},
		{`{"platform":"desktop_web","direction":"connection","state":"playing","rtt_ms":12}`, 204},
	} {
		response := httptest.NewRecorder()
		handler.ServeHTTP(response, httptest.NewRequest("POST", "/", strings.NewReader(test.body)))
		if response.Code != test.status {
			t.Fatal(response.Code)
		}
	}
	var data metricdata.ResourceMetrics
	if err := reader.Collect(context.Background(), &data); err != nil {
		t.Fatal(err)
	}
	found := false
	for _, scope := range data.ScopeMetrics {
		for _, metric := range scope.Metrics {
			if metric.Name == "boohtacord_media_rtt_milliseconds" {
				points := metric.Data.(metricdata.Histogram[float64]).DataPoints
				if len(points) != 1 || points[0].Count != 1 || points[0].Sum != 42 {
					t.Fatal(points)
				}
				found = true
			}
		}
	}
	if !found {
		t.Fatal("accepted QoE did not reach existing OTEL exporter channel")
	}
}
