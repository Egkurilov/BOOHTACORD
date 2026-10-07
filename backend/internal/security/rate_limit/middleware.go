package ratelimit

import (
	"encoding/json"
	"math"
	"net/http"
	"strconv"
	"time"

	"voice-platform/backend/internal/security/request_id"
)

func writeRateLimit(writer http.ResponseWriter, request *http.Request, retryAfter time.Duration) {
	writer.Header().Set("Content-Type", "application/json; charset=utf-8")
	writer.Header().Set("Retry-After", retryAfterSeconds(retryAfter))
	writer.WriteHeader(http.StatusTooManyRequests)
	_ = json.NewEncoder(writer).Encode(map[string]any{"error": map[string]string{
		"code": "RATE_LIMITED", "message": "Слишком много попыток; повторите позже",
		"request_id": requestid.From(request.Context()),
	}})
}

func WriteLimited(writer http.ResponseWriter, request *http.Request, retryAfter time.Duration) {
	writeRateLimit(writer, request, retryAfter)
}

func retryAfterSeconds(duration time.Duration) string {
	return strconv.Itoa(max(1, int(math.Ceil(duration.Seconds()))))
}

func RetryAfterSeconds(duration time.Duration) string { return retryAfterSeconds(duration) }
