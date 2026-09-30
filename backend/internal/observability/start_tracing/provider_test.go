package starttracing

import (
	"context"
	"io"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"go.opentelemetry.io/otel"
)

func TestStartWithoutEndpointLeavesTracingUnchanged(t *testing.T) {
	t.Setenv("OTEL_EXPORTER_OTLP_ENDPOINT", "")
	t.Setenv("OTEL_EXPORTER_OTLP_TRACES_ENDPOINT", "")
	before := otel.GetTracerProvider()
	shutdown, err := Start(context.Background())
	if err != nil || shutdown == nil || otel.GetTracerProvider() != before {
		t.Fatalf("disabled tracing changed provider: %v", err)
	}
	if err := shutdown(context.Background()); err != nil {
		t.Fatal(err)
	}
}

func TestStartExportsSpanToConfiguredEndpoint(t *testing.T) {
	type export struct {
		authorization, contentType string
		bytes                      int
	}
	received := make(chan export, 1)
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		body, _ := io.ReadAll(r.Body)
		received <- export{r.Header.Get("Authorization"), r.Header.Get("Content-Type"), len(body)}
		w.WriteHeader(http.StatusOK)
	}))
	defer server.Close()
	t.Setenv("OTEL_EXPORTER_OTLP_ENDPOINT", "")
	t.Setenv("OTEL_EXPORTER_OTLP_TRACES_ENDPOINT", server.URL)
	t.Setenv("OTEL_EXPORTER_OTLP_PROTOCOL", "http/protobuf")
	t.Setenv("OTEL_INGEST_AUTH", "Bearer test-trace")
	oldProvider := otel.GetTracerProvider()
	oldPropagator := otel.GetTextMapPropagator()
	t.Cleanup(func() {
		otel.SetTracerProvider(oldProvider)
		otel.SetTextMapPropagator(oldPropagator)
	})

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	shutdown, err := Start(ctx)
	if err != nil {
		t.Fatal(err)
	}
	_, span := otel.Tracer("test/export").Start(ctx, "test.trace")
	span.End()
	if err := shutdown(ctx); err != nil {
		t.Fatal(err)
	}
	select {
	case got := <-received:
		if got.authorization != "Bearer test-trace" || got.contentType != "application/x-protobuf" || got.bytes == 0 {
			t.Fatalf("invalid trace export: %+v", got)
		}
	default:
		t.Fatal("trace exporter sent no request")
	}
}
