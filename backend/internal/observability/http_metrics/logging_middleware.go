package httpmetrics

import (
	"log/slog"
	"net/http"
	"time"

	"voice-platform/backend/internal/observability/skip_requests"
	"voice-platform/backend/internal/security/request_id"
)

func LoggingMiddleware(logger *slog.Logger, next http.Handler) http.Handler {
	if logger == nil {
		logger = slog.Default()
	}
	return http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		if skiprequests.Skip(request) {
			next.ServeHTTP(writer, request)
			return
		}
		started := time.Now()
		captured := &responseWriter{ResponseWriter: writer}
		next.ServeHTTP(captured, request)
		logger.Info("http.request.completed",
			"request_id", requestid.From(request.Context()),
			"method", request.Method,
			"status", captured.statusCode(),
			"duration_ms", time.Since(started).Milliseconds(),
		)
	})
}
