package welcomepostgres

import (
	"bytes"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracehttp"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	collectortrace "go.opentelemetry.io/proto/otlp/collector/trace/v1"
	tracepb "go.opentelemetry.io/proto/otlp/trace/v1"
	"google.golang.org/protobuf/proto"
	"io"
	"net/http"
	"net/http/httptest"
	"testing"
)

func newOTLPRecorder(t *testing.T) (*sdktrace.TracerProvider, chan *collectortrace.ExportTraceServiceRequest) {
	t.Helper()
	received := make(chan *collectortrace.ExportTraceServiceRequest, 8)
	collector := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		payload, err := io.ReadAll(r.Body)
		if err != nil {
			t.Error(err)
			w.WriteHeader(500)
			return
		}
		var batch collectortrace.ExportTraceServiceRequest
		if err = proto.Unmarshal(payload, &batch); err != nil {
			t.Error(err)
			w.WriteHeader(400)
			return
		}
		if bytes.Contains(payload, []byte("PRIVATE_PASSWORD_VALID")) {
			t.Error("password exported")
		}
		received <- &batch
		w.Header().Set("Content-Type", "application/x-protobuf")
		w.WriteHeader(200)
	}))
	t.Cleanup(collector.Close)
	exporter, err := otlptracehttp.New(t.Context(), otlptracehttp.WithEndpointURL(collector.URL), otlptracehttp.WithInsecure())
	if err != nil {
		t.Fatal(err)
	}
	provider := sdktrace.NewTracerProvider(sdktrace.WithSyncer(exporter))
	t.Cleanup(func() { _ = provider.Shutdown(t.Context()) })
	return provider, received
}
func otlpAttributes(span *tracepb.Span) map[string]string {
	result := map[string]string{}
	for _, attr := range span.Attributes {
		result[attr.Key] = attr.Value.GetStringValue()
	}
	return result
}
