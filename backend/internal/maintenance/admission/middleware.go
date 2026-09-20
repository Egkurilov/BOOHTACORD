package maintenanceadmission

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"

	"voice-platform/backend/internal/security/request_id"
)

type Admitter interface {
	RequireOpen(context.Context) error
}

func Middleware(admitter Admitter) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
			if err := admitter.RequireOpen(request.Context()); err != nil {
				writeAdmissionError(writer, request, err)
				return
			}
			next.ServeHTTP(writer, request)
		})
	}
}

func writeAdmissionError(writer http.ResponseWriter, request *http.Request, err error) {
	code, message := "MAINTENANCE_UNAVAILABLE", "Новые входы и подключения временно недоступны"
	if errors.Is(err, ErrMaintenanceActive) {
		code, message = "MAINTENANCE", "Новые входы и подключения временно приостановлены из-за обслуживания"
	}
	writer.Header().Set("Content-Type", "application/json; charset=utf-8")
	writer.WriteHeader(http.StatusServiceUnavailable)
	_ = json.NewEncoder(writer).Encode(map[string]any{"error": map[string]string{
		"code":       code,
		"message":    message,
		"request_id": requestid.From(request.Context()),
	}})
}
