package tracehttp

import (
	"net/http"
	"strconv"
	"time"

	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/codes"
	"go.opentelemetry.io/otel/metric"
	"go.opentelemetry.io/otel/trace"
	"voice-platform/backend/internal/observability/skip_requests"
)

// Middleware creates one span per API request; ServeMux templates keep private IDs out of span names.
func Middleware(tracer trace.Tracer, mux *http.ServeMux, next http.Handler) http.Handler {
	meter := otel.Meter("boohtacord/http")
	requests, _ := meter.Int64Counter("boohtacord.http.server.requests")
	duration, _ := meter.Float64Histogram("boohtacord.http.server.duration", metric.WithUnit("s"),
		metric.WithExplicitBucketBoundaries(0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5))
	return http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		if skiprequests.Skip(request) {
			next.ServeHTTP(writer, request)
			return
		}
		_, pattern := mux.Handler(request)
		method := safeMethod(request.Method)
		name := pattern
		if pattern == "" {
			pattern = "unmatched"
			name = method + " unmatched"
		}
		context := remoteContext(request)
		context, span := tracer.Start(context, name, trace.WithSpanKind(trace.SpanKindServer))
		if pattern == "PATCH /api/v1/admin/guild-settings" {
			context = withGuildActions(context)
		}
		started := time.Now()
		captured := &statusWriter{ResponseWriter: writer, onUpgrade: func(...trace.SpanEndOption) {
			span.SetAttributes(attribute.Int("http.response.status_code", http.StatusSwitchingProtocols))
			span.End()
		}}
		defer func() {
			panicValue := recover()
			status := captured.code
			if panicValue != nil {
				status = http.StatusInternalServerError
			} else if status == 0 {
				status = http.StatusOK
			}
			labels := metric.WithAttributes(attribute.String("http.request.method", method), attribute.String("http.route", pattern), attribute.Int("http.response.status_code", status))
			requests.Add(context, 1, labels)
			duration.Record(context, time.Since(started).Seconds(), labels)
			span.SetAttributes(attribute.Int("http.response.status_code", status))
			if pattern == "PATCH /api/v1/admin/guild-settings" {
				recordGuildActions(context, span, status)
			} else {
				recordApplicationEvent(span, pattern, status)
			}
			if panicValue != nil {
				span.SetStatus(codes.Error, "panic")
			} else if status >= 500 {
				span.SetStatus(codes.Error, "HTTP "+strconv.Itoa(status))
			}
			span.End()
			if panicValue != nil {
				panic(panicValue)
			}
		}()
		span.SetAttributes(attribute.String("http.request.method", method), attribute.String("http.route", pattern))
		next.ServeHTTP(captured, request.WithContext(context))
	})
}

func safeMethod(method string) string {
	switch method {
	case http.MethodGet, http.MethodHead, http.MethodPost, http.MethodPut, http.MethodPatch, http.MethodDelete, http.MethodOptions:
		return method
	default:
		return "OTHER"
	}
}

type statusWriter struct {
	http.ResponseWriter
	code      int
	onUpgrade func(...trace.SpanEndOption)
}

func (writer *statusWriter) Unwrap() http.ResponseWriter { return writer.ResponseWriter }

func (writer *statusWriter) WriteHeader(status int) {
	if writer.code == 0 {
		writer.code = status
	}
	writer.ResponseWriter.WriteHeader(status)
	if status == http.StatusSwitchingProtocols && writer.onUpgrade != nil {
		writer.onUpgrade()
		writer.onUpgrade = nil
	}
}

func (writer *statusWriter) Write(value []byte) (int, error) {
	if writer.code == 0 {
		writer.code = http.StatusOK
	}
	return writer.ResponseWriter.Write(value)
}
