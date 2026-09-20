package maintenanceadmissionapi

import (
	"context"
	"encoding/json"
	"net/http"

	"voice-platform/backend/internal/security/request_id"
)

type StateReader interface {
	Active(context.Context) (bool, error)
}

func NewHandler(reader StateReader) http.Handler {
	return http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		if request.Method != http.MethodGet {
			writer.WriteHeader(http.StatusMethodNotAllowed)
			return
		}
		active, err := reader.Active(request.Context())
		if err != nil {
			writer.Header().Set("Content-Type", "application/json; charset=utf-8")
			writer.WriteHeader(http.StatusServiceUnavailable)
			_ = json.NewEncoder(writer).Encode(map[string]any{"error": map[string]string{
				"code":       "MAINTENANCE_UNAVAILABLE",
				"message":    "Статус обслуживания временно недоступен",
				"request_id": requestid.From(request.Context()),
			}})
			return
		}
		writer.Header().Set("Cache-Control", "no-store")
		writer.Header().Set("Content-Type", "application/json; charset=utf-8")
		_ = json.NewEncoder(writer).Encode(struct {
			Active bool `json:"active"`
		}{Active: active})
	})
}
