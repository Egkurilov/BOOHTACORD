package ratelimit

import (
	"encoding/json"
	"math"
	"net"
	"net/http"
	"strconv"
	"strings"
	"time"

	"voice-platform/backend/internal/security/request_id"
)

func (limiter *Limiter) Middleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		retryAfter, allowed := limiter.allow(sourceKey(request))
		if !allowed {
			writer.Header().Set("Content-Type", "application/json; charset=utf-8")
			writer.Header().Set("Retry-After", retryAfterSeconds(retryAfter))
			writer.WriteHeader(http.StatusTooManyRequests)
			_ = json.NewEncoder(writer).Encode(map[string]any{"error": map[string]string{
				"code":       "RATE_LIMITED",
				"message":    "Слишком много попыток; повторите позже",
				"request_id": requestid.From(request.Context()),
			}})
			return
		}
		next.ServeHTTP(writer, request)
	})
}

func sourceKey(request *http.Request) string {
	forwarded := strings.TrimSpace(strings.Split(request.Header.Get("X-Forwarded-For"), ",")[0])
	if net.ParseIP(forwarded) != nil {
		return forwarded
	}
	host, _, err := net.SplitHostPort(request.RemoteAddr)
	if err == nil {
		return host
	}
	return request.RemoteAddr
}

func retryAfterSeconds(duration time.Duration) string {
	return strconv.Itoa(max(1, int(math.Ceil(duration.Seconds()))))
}
