package managevoicetimeoutapi

import (
	"encoding/json"
	"errors"
	"net/http"
	requestid "voice-platform/backend/internal/security/request_id"
	timeout "voice-platform/backend/internal/voice/manage_voice_timeout"
)

func writeError(w http.ResponseWriter, r *http.Request, err error) {
	status, code, message := 500, "INTERNAL", "Не удалось обновить ограничение голоса"
	switch {
	case errors.Is(err, timeout.ErrInvalidInput):
		status, code, message = 400, "VALIDATION_FAILED", "Некорректное ограничение голоса"
	case errors.Is(err, timeout.ErrUnauthenticated):
		status, code, message = 401, "UNAUTHENTICATED", "Сессия больше не активна"
	case errors.Is(err, timeout.ErrForbidden):
		status, code, message = 403, "FORBIDDEN", "Недостаточно прав"
	case errors.Is(err, timeout.ErrNotFound):
		status, code, message = 404, "NOT_FOUND", "Участник недоступен"
	}
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.Header().Set("Cache-Control", "no-store")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(map[string]any{"error": map[string]string{"code": code, "message": message, "request_id": requestid.From(r.Context())}})
}
