package listauditeventsapi

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"strconv"

	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	"voice-platform/backend/internal/identity/list_audit_events"
	"voice-platform/backend/internal/security/request_id"
)

type Reader interface {
	List(context.Context, listauditevents.Input) (listauditevents.Result, error)
}

func NewHandler(reader Reader) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if _, ok := sessionapi.PrincipalFrom(r.Context()); !ok {
			writeError(w, r, http.StatusUnauthorized, "UNAUTHENTICATED", "Требуется вход")
			return
		}
		limit, err := queryLimit(r)
		if err != nil {
			writeError(w, r, http.StatusBadRequest, "VALIDATION_FAILED", "Некорректная страница аудита")
			return
		}
		result, err := reader.List(r.Context(), listauditevents.Input{Before: r.URL.Query().Get("before"), Limit: limit})
		if errors.Is(err, listauditevents.ErrInvalidInput) {
			writeError(w, r, http.StatusBadRequest, "VALIDATION_FAILED", "Некорректная страница аудита")
			return
		}
		if err != nil {
			writeError(w, r, http.StatusInternalServerError, "INTERNAL", "Не удалось загрузить аудит")
			return
		}
		w.Header().Set("Content-Type", "application/json; charset=utf-8")
		_ = json.NewEncoder(w).Encode(result)
	})
}

func queryLimit(r *http.Request) (int, error) {
	value := r.URL.Query().Get("limit")
	if value == "" {
		return 0, nil
	}
	limit, err := strconv.Atoi(value)
	if err != nil || limit < 1 || limit > 100 {
		return 0, listauditevents.ErrInvalidInput
	}
	return limit, nil
}

func writeError(w http.ResponseWriter, r *http.Request, status int, code, message string) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(map[string]any{"error": map[string]string{"code": code, "message": message, "request_id": requestid.From(r.Context())}})
}
