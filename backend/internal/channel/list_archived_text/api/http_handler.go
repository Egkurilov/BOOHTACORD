package listarchivedtextapi

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"strconv"
	list "voice-platform/backend/internal/channel/list_archived_text"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	requestid "voice-platform/backend/internal/security/request_id"
)

type Lister interface {
	List(context.Context, list.Input) (list.Result, error)
}

func NewHandler(service Lister) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		principal, ok := sessionapi.PrincipalFrom(r.Context())
		if !ok {
			writeError(w, r, http.StatusInternalServerError, "INTERNAL")
			return
		}
		for _, name := range []string{"cursor", "limit"} {
			if values, present := r.URL.Query()[name]; present && (len(values) != 1 || values[0] == "") {
				writeError(w, r, http.StatusBadRequest, "VALIDATION_FAILED")
				return
			}
		}
		limit := 50
		if value := r.URL.Query().Get("limit"); value != "" {
			var err error
			limit, err = strconv.Atoi(value)
			if err != nil {
				writeError(w, r, http.StatusBadRequest, "VALIDATION_FAILED")
				return
			}
		}
		result, err := service.List(r.Context(), list.Input{ActorID: principal.AccountID, Cursor: r.URL.Query().Get("cursor"), Limit: limit})
		if errors.Is(err, list.ErrInvalidInput) {
			writeError(w, r, http.StatusBadRequest, "VALIDATION_FAILED")
			return
		}
		if err != nil {
			writeError(w, r, http.StatusInternalServerError, "INTERNAL")
			return
		}
		result.CanManage = principal.Role == "ADMINISTRATOR"
		w.Header().Set("Content-Type", "application/json; charset=utf-8")
		w.Header().Set("Cache-Control", "no-store")
		json.NewEncoder(w).Encode(result)
	})
}
func writeError(w http.ResponseWriter, r *http.Request, status int, code string) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(map[string]any{"error": map[string]string{"code": code, "message": "Не удалось загрузить архив", "request_id": requestid.From(r.Context())}})
}
