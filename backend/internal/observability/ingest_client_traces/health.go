package ingestclienttraces

import (
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/metric"
	"net/http"
	"time"
)

var relayRequests, _ = otel.Meter("boohtacord/relay").Int64Counter("boohtacord.telemetry.relay.requests")
var relayLatency, _ = otel.Meter("boohtacord/relay").Float64Histogram("boohtacord.telemetry.relay.duration", metric.WithUnit("s"))
var relayFreshness, _ = otel.Meter("boohtacord/relay").Int64Gauge("boohtacord.telemetry.relay.last_accept", metric.WithUnit("s"))

type healthWriter struct {
	http.ResponseWriter
	status int
}

func (w *healthWriter) WriteHeader(status int) {
	if w.status == 0 {
		w.status = status
	}
	w.ResponseWriter.WriteHeader(status)
}
func (w *healthWriter) Write(body []byte) (int, error) {
	if w.status == 0 {
		w.status = 200
	}
	return w.ResponseWriter.Write(body)
}
func withRelayHealth(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		started := time.Now()
		captured := &healthWriter{ResponseWriter: w}
		defer func() {
			code := captured.status
			if code == 0 {
				code = 200
			}
			labels := metric.WithAttributes(attribute.Int("http.response.status_code", code))
			relayRequests.Add(r.Context(), 1, labels)
			relayLatency.Record(r.Context(), time.Since(started).Seconds(), labels)
			if code == 202 && captured.Header().Get("X-Telemetry-Accepted") != "0" {
				relayFreshness.Record(r.Context(), time.Now().Unix())
			}
		}()
		next.ServeHTTP(captured, r)
	})
}
