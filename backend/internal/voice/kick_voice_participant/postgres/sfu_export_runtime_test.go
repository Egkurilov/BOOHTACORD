package kickvoiceparticipantpostgres

import (
	"context"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracehttp"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	"io"
	"net"
	"net/http"
	"net/url"
	"os"
	"strings"
	"testing"
	"time"
)

func runtimeExporter(t *testing.T) sdktrace.TracerProviderOption {
	t.Helper()
	collector := privateRuntimeURL(t, "TRACE_QA_COLLECTOR_URL")
	exporter, err := otlptracehttp.New(context.Background(), otlptracehttp.WithEndpointURL(collector+"/v1/traces"), otlptracehttp.WithInsecure(), otlptracehttp.WithTimeout(3*time.Second))
	if err != nil {
		t.Fatal(err)
	}
	return sdktrace.WithSyncer(exporter)
}

func verifyWorkerStored(t *testing.T, spans []sdktrace.ReadOnlySpan) {
	t.Helper()
	tempo := privateRuntimeURL(t, "TRACE_QA_TEMPO_URL")
	client := &http.Client{Timeout: 2 * time.Second, Transport: &http.Transport{Proxy: nil}}
	for _, span := range spans {
		id := span.SpanContext().TraceID().String()
		found := false
		deadline := time.Now().Add(15 * time.Second)
		for time.Now().Before(deadline) {
			response, err := client.Get(tempo + "/api/traces/" + id)
			if err == nil {
				body, _ := io.ReadAll(io.LimitReader(response.Body, 1<<20))
				response.Body.Close()
				if response.StatusCode == 200 && strings.Contains(string(body), span.Name()) {
					if span.Name() == "voice.sfu_revocation.attempt" && !strings.Contains(string(body), "links") {
						t.Fatal("stored worker missing original link")
					}
					for _, secret := range []string{"synthetic-qa-only-secret", "Bearer ", "Authorization"} {
						if strings.Contains(string(body), secret) {
							t.Fatal("secret exported")
						}
					}
					found = true
					t.Logf("stored actual worker graph trace=%s operation=%s", id, span.Name())
					break
				}
			}
			time.Sleep(250 * time.Millisecond)
		}
		if !found {
			t.Fatal("worker graph absent from Tempo")
		}
	}
}

func privateRuntimeURL(t *testing.T, key string) string {
	t.Helper()
	raw := os.Getenv(key)
	if raw == "" {
		t.Skip("isolated runtime endpoint required: " + key)
	}
	parsed, err := url.Parse(raw)
	if err != nil || parsed.Scheme != "http" || parsed.User != nil {
		t.Fatal("expected synthetic QA URL")
	}
	ip := net.ParseIP(parsed.Hostname())
	if ip == nil || (!ip.IsPrivate() && !ip.IsLoopback()) {
		t.Fatal("QA endpoint must be private")
	}
	return strings.TrimRight(raw, "/")
}
