package bindflow

import (
	"context"
	"go.opentelemetry.io/otel/sdk/trace"
	"go.opentelemetry.io/otel/sdk/trace/tracetest"
	"net/http"
	"testing"
)

func TestSessionBindingNeverTrustsForeignOrMalformedClaims(t *testing.T) {
	recorder := tracetest.NewSpanRecorder()
	provider := trace.NewTracerProvider(trace.WithSpanProcessor(recorder))
	defer provider.Shutdown(context.Background())
	headers := http.Header{"X-Telemetry-Session": {"11111111111111111111111111111111"}, "X-App-Visit": {"22222222222222222222222222222222"}, "X-App-Flow": {"33333333333333333333333333333333"}, "X-App-Flow-Name": {"message.send"}, "X-App-Attempt": {"1"}}
	ctx, span := provider.Tracer("test").Start(context.Background(), "request")
	for _, bad := range []string{"", "44444444444444444444444444444444", "private-cookie"} {
		if _, ok := From(Bind(ctx, headers, bad)); ok {
			t.Fatal("spoof trusted")
		}
	}
	bound := Bind(ctx, headers, "11111111111111111111111111111111")
	if flow, ok := From(bound); !ok || flow.Name != "message.send" {
		t.Fatal("valid missing")
	}
	headers.Set("X-App-Flow", "secret")
	if _, ok := From(Bind(ctx, headers, "11111111111111111111111111111111")); ok {
		t.Fatal("invalid trusted")
	}
	span.End()
	for _, a := range recorder.Ended()[0].Attributes() {
		if a.Value.AsString() == "secret" {
			t.Fatal("secret exported")
		}
	}
}
