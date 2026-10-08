package listtextpinsapi

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"strconv"
	list "voice-platform/backend/internal/chat/list_text_pins"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	requestid "voice-platform/backend/internal/security/request_id"
)

type Lister interface {
	List(context.Context, list.Input) (list.Result, error)
}

func NewHandler(service Lister) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Cache-Control", "no-store")
		principal, ok := sessionapi.PrincipalFrom(r.Context())
		if !ok {
			writeError(w, r, 403, "FORBIDDEN")
			return
		}
		limit := 50
		for _, name := range []string{"before", "limit"} {
			if values, present := r.URL.Query()[name]; present && (len(values) != 1 || values[0] == "") {
				writeError(w, r, 400, "VALIDATION_FAILED")
				return
			}
		}
		if value := r.URL.Query().Get("limit"); value != "" {
			parsed, err := strconv.Atoi(value)
			if err != nil {
				writeError(w, r, 400, "VALIDATION_FAILED")
				return
			}
			limit = parsed
		}
		result, err := service.List(r.Context(), list.Input{ActorID: principal.AccountID, ChannelID: r.PathValue("channelID"), Limit: limit, Before: r.URL.Query().Get("before")})
		if errors.Is(err, list.ErrInvalidInput) {
			writeError(w, r, 400, "VALIDATION_FAILED")
			return
		}
		if errors.Is(err, list.ErrUnavailable) {
			writeError(w, r, 404, "NOT_FOUND")
			return
		}
		if err != nil {
			writeError(w, r, 500, "INTERNAL")
			return
		}
		result.CanManage = principal.Role == "ADMINISTRATOR"
		w.Header().Set("Content-Type", "application/json; charset=utf-8")
		json.NewEncoder(w).Encode(result)
	})
}
func writeError(w http.ResponseWriter, r *http.Request, status int, code string) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(map[string]any{"error": map[string]string{"code": code, "message": "Не удалось получить закрепления", "request_id": requestid.From(r.Context())}})
}
