package httpmetrics

import (
	"bufio"
	"io"
	"net"
	"net/http"
	"strconv"
	"time"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

type Recorder struct {
	attachmentFilesystemRegistered bool
	duration                       *prometheus.HistogramVec
	handler                        http.Handler
	registry                       *prometheus.Registry
	requests                       *prometheus.CounterVec
	realtime                       *realtimeConnections
	uploadFailures                 *uploadFailureMetrics
	voiceSFURevocations            *prometheus.CounterVec
}

func New() *Recorder {
	registry := prometheus.NewRegistry()
	requests := prometheus.NewCounterVec(prometheus.CounterOpts{
		Name: "voice_platform_api_requests_total",
		Help: "Completed API requests by method and status.",
	}, []string{"method", "status"})
	duration := prometheus.NewHistogramVec(prometheus.HistogramOpts{
		Name: "voice_platform_api_request_duration_seconds",
		Help: "Completed API request durations by method and status.",
	}, []string{"method", "status"})
	voiceSFURevocations := prometheus.NewCounterVec(prometheus.CounterOpts{
		Name: "voice_platform_voice_sfu_revocations_total",
		Help: "Durable SFU revocation dispatch outcomes.",
	}, []string{"outcome"})
	realtime := newRealtimeConnections()
	uploadFailures := newUploadFailureMetrics()
	registry.MustRegister(requests, duration, voiceSFURevocations, realtime.active, realtime.total, realtime.ready, uploadFailures.total)
	return &Recorder{duration: duration, handler: promhttp.HandlerFor(registry, promhttp.HandlerOpts{}), realtime: realtime, registry: registry, requests: requests, uploadFailures: uploadFailures, voiceSFURevocations: voiceSFURevocations}
}

func (recorder *Recorder) Handler() http.Handler { return recorder.handler }

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

type responseWriter struct {
	http.ResponseWriter
	status int
}

func (writer *responseWriter) Unwrap() http.ResponseWriter { return writer.ResponseWriter }

func (writer *responseWriter) WriteHeader(status int) {
	if writer.status == 0 {
		writer.status = status
	}
	writer.ResponseWriter.WriteHeader(status)
}

func (writer *responseWriter) Write(value []byte) (int, error) {
	if writer.status == 0 {
		writer.WriteHeader(http.StatusOK)
	}
	return writer.ResponseWriter.Write(value)
}

func (writer *responseWriter) Flush() {
	if flusher, ok := writer.ResponseWriter.(http.Flusher); ok {
		flusher.Flush()
	}
}

func (writer *responseWriter) Hijack() (net.Conn, *bufio.ReadWriter, error) {
	if hijacker, ok := writer.ResponseWriter.(http.Hijacker); ok {
		return hijacker.Hijack()
	}
	return nil, nil, http.ErrNotSupported
}

func (writer *responseWriter) Push(target string, options *http.PushOptions) error {
	if pusher, ok := writer.ResponseWriter.(http.Pusher); ok {
		return pusher.Push(target, options)
	}
	return http.ErrNotSupported
}

func (writer *responseWriter) ReadFrom(source io.Reader) (int64, error) {
	if writer.status == 0 {
		writer.WriteHeader(http.StatusOK)
	}
	if reader, ok := writer.ResponseWriter.(io.ReaderFrom); ok {
		return reader.ReadFrom(source)
	}
	return io.Copy(writer.ResponseWriter, source)
}

func (writer *responseWriter) statusCode() int {
	if writer.status == 0 {
		return http.StatusOK
	}
	return writer.status
}
