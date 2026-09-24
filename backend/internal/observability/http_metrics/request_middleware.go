package httpmetrics

import (
	"net/http"
	"strconv"
	"time"

	"github.com/prometheus/client_golang/prometheus"
)

func (recorder *Recorder) Middleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		if request.URL.Path == "/metrics" {
			next.ServeHTTP(writer, request)
			return
		}
		started := time.Now()
		captured := &responseWriter{ResponseWriter: writer}
		next.ServeHTTP(captured, request)
		status := strconv.Itoa(captured.statusCode())
		labels := prometheus.Labels{"method": request.Method, "status": status}
		recorder.requests.With(labels).Inc()
		recorder.duration.With(labels).Observe(time.Since(started).Seconds())
	})
}
