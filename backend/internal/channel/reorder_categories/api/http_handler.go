package reorderapi

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"

	"voice-platform/backend/internal/channel/reorder_categories"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	"voice-platform/backend/internal/security/request_id"
)

type Reorderer interface {
	Reorder(context.Context, reordercategories.Input) (reordercategories.Result, error)
}

func NewHandler(reorderer Reorderer) http.Handler {
	return http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		if request.Method != http.MethodPut {
			writer.WriteHeader(http.StatusMethodNotAllowed)
			return
		}
		principal, ok := sessionapi.PrincipalFrom(request.Context())
		if !ok {
			writeError(writer, request, http.StatusInternalServerError, "INTERNAL", "Не удалось изменить порядок категорий")
			return
		}
		var body struct {
			ExpectedRevision int64    `json:"expected_revision"`
			IDs              []string `json:"ids"`
		}
		decoder := json.NewDecoder(http.MaxBytesReader(writer, request.Body, 32<<10))
		decoder.DisallowUnknownFields()
		if err := decoder.Decode(&body); err != nil {
			writeError(writer, request, http.StatusBadRequest, "VALIDATION_FAILED", "Некорректный порядок категорий")
			return
		}
		result, err := reorderer.Reorder(request.Context(), reordercategories.Input{ActorID: principal.AccountID, ExpectedRevision: body.ExpectedRevision, IDs: body.IDs})
		if errors.Is(err, reordercategories.ErrInvalidInput) {
			writeError(writer, request, http.StatusBadRequest, "VALIDATION_FAILED", "Некорректный порядок категорий")
			return
		}
		if errors.Is(err, reordercategories.ErrRevisionConflict) {
			writeError(writer, request, http.StatusConflict, "CONFLICT", "Конфликт ревизии; обновите состояние и повторите действие")
			return
		}
		if err != nil {
			writeError(writer, request, http.StatusInternalServerError, "INTERNAL", "Не удалось изменить порядок категорий")
			return
		}
		writer.Header().Set("Content-Type", "application/json; charset=utf-8")
		_ = json.NewEncoder(writer).Encode(struct {
			Revision int64 `json:"revision"`
		}{result.Revision})
	})
}

func writeError(writer http.ResponseWriter, request *http.Request, status int, code, message string) {
	writer.Header().Set("Content-Type", "application/json; charset=utf-8")
	writer.WriteHeader(status)
	_ = json.NewEncoder(writer).Encode(map[string]any{"error": map[string]string{
		"code":       code,
		"message":    message,
		"request_id": requestid.From(request.Context()),
	}})
}
