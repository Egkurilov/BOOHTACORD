package deleteemptycategoryapi

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"strconv"

	deleteemptycategory "voice-platform/backend/internal/channel/delete_empty_category"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	"voice-platform/backend/internal/security/request_id"
)

type Deleter interface {
	Delete(context.Context, deleteemptycategory.Input) (deleteemptycategory.Result, error)
}

func NewHandler(deleter Deleter) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		p, ok := sessionapi.PrincipalFrom(r.Context())
		if !ok {
			writeError(w, r, http.StatusInternalServerError, "INTERNAL", "Не удалось удалить категорию")
			return
		}
		revision, err := strconv.ParseInt(r.URL.Query().Get("expected_revision"), 10, 64)
		if err != nil {
			writeError(w, r, http.StatusBadRequest, "VALIDATION_FAILED", "Некорректная ревизия топологии")
			return
		}
		result, err := deleter.Delete(r.Context(), deleteemptycategory.Input{ActorID: p.AccountID, CategoryID: r.PathValue("categoryID"), ExpectedRevision: revision})
		if errors.Is(err, deleteemptycategory.ErrInvalidInput) {
			writeError(w, r, http.StatusBadRequest, "VALIDATION_FAILED", "Некорректные параметры удаления категории")
			return
		}
		if errors.Is(err, deleteemptycategory.ErrRevisionConflict) {
			writeError(w, r, http.StatusConflict, "CONFLICT", "Категория не пуста, не существует или состояние устарело")
			return
		}
		if err != nil {
			writeError(w, r, http.StatusInternalServerError, "INTERNAL", "Не удалось удалить категорию")
			return
		}
		w.Header().Set("Content-Type", "application/json; charset=utf-8")
		_ = json.NewEncoder(w).Encode(result)
	})
}
func writeError(w http.ResponseWriter, r *http.Request, status int, code, message string) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(map[string]any{"error": map[string]string{"code": code, "message": message, "request_id": requestid.From(r.Context())}})
}
