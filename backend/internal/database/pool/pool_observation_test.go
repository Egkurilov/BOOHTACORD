package pool

import (
	"context"
	"encoding/json"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/exporters/otlp/otlpmetric/otlpmetrichttp"
	sdkmetric "go.opentelemetry.io/otel/sdk/metric"
	"go.opentelemetry.io/otel/sdk/metric/metricdata"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"strings"
	"testing"
	"time"
)

func TestLivePoolStatsAndCanceledAcquireReachBothTransports(t *testing.T) {
	received := make(chan []byte, 2)
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		body, _ := io.ReadAll(r.Body)
		received <- body
		w.WriteHeader(200)
	}))
	defer server.Close()
	exporter, err := otlpmetrichttp.New(t.Context(), otlpmetrichttp.WithEndpointURL(server.URL))
	if err != nil {
		t.Fatal(err)
	}
	reader := sdkmetric.NewManualReader()
	provider := sdkmetric.NewMeterProvider(sdkmetric.WithReader(reader), sdkmetric.WithReader(sdkmetric.NewPeriodicReader(exporter, sdkmetric.WithInterval(time.Hour))))
	old := otel.GetMeterProvider()
	otel.SetMeterProvider(provider)
	defer func() { otel.SetMeterProvider(old); provider.Shutdown(t.Context()) }()
	m := NewMetrics()
	config, err := pgxpool.ParseConfig("postgres://unused@127.0.0.1:1/test?sslmode=disable")
	if err != nil {
		t.Fatal(err)
	}
	config.MaxConns = 1
	config.ConnConfig.Tracer = m
	database, err := pgxpool.NewWithConfig(t.Context(), config)
	if err != nil {
		t.Fatal(err)
	}
	defer database.Close()
	m.pool = database
	m.startExport()
	defer m.StopExport()
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	if _, err := database.Acquire(ctx); err == nil {
		t.Fatal("canceled acquisition accepted")
	}
	registry := prometheus.NewRegistry()
	registry.MustRegister(m)
	w := httptest.NewRecorder()
	promhttp.HandlerFor(registry, promhttp.HandlerOpts{}).ServeHTTP(w, httptest.NewRequest("GET", "/", nil))
	out := w.Body.String()
	for _, want := range []string{"voice_platform_database_pool_max 1", "voice_platform_database_pool_total 0", `outcome="canceled"} 1`} {
		if !strings.Contains(out, want) {
			t.Fatal(out)
		}
	}
	if err := provider.ForceFlush(t.Context()); err != nil {
		t.Fatal(err)
	}
	payload := <-received
	if path := os.Getenv("INCIDENT_POOL_OTLP_FIXTURE"); path != "" {
		if err := os.WriteFile(path, payload, 0600); err != nil {
			t.Fatal(err)
		}
	}
	var data metricdata.ResourceMetrics
	if err := reader.Collect(t.Context(), &data); err != nil {
		t.Fatal(err)
	}
	encoded, _ := json.Marshal(data)
	out = string(encoded)
	for _, want := range []string{"boohtacord.incident.database.acquires", "boohtacord.incident.database.pool", "canceled"} {
		if !strings.Contains(out, want) {
			t.Fatal(out)
		}
	}
	if strings.Contains(out, "127.0.0.1") || strings.Contains(out, "unused") {
		t.Fatal("connection leaked")
	}
}
