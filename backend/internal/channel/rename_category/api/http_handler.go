package renameapi

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"

	"voice-platform/backend/internal/channel/rename_category"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	"voice-platform/backend/internal/security/request_id"
)

type Renamer interface {
	Rename(context.Context, renamecategory.Input) (renamecategory.Result, error)
}

func NewHandler(renamer Renamer) http.Handler {
	return http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		if request.Method != http.MethodPatch {
			writer.WriteHeader(http.StatusMethodNotAllowed)
			return
		}
		principal, ok := sessionapi.PrincipalFrom(request.Context())
		if !ok {
			writeError(writer, request, http.StatusInternalServerError, "INTERNAL", "Не удалось переименовать категорию")
			return
		}
		var body struct {
			Name             string `json:"name"`
			ExpectedRevision int64  `json:"expected_revision"`
		}
		decoder := json.NewDecoder(http.MaxBytesReader(writer, request.Body, 8<<10))
		decoder.DisallowUnknownFields()
		if err := decoder.Decode(&body); err != nil {
			writeError(writer, request, http.StatusBadRequest, "VALIDATION_FAILED", "Некорректное имя категории")
			return
		}
		result, err := renamer.Rename(request.Context(), renamecategory.Input{ActorID: principal.AccountID, CategoryID: request.PathValue("categoryID"), Name: body.Name, ExpectedRevision: body.ExpectedRevision})
		if errors.Is(err, renamecategory.ErrInvalidInput) {
			writeError(writer, request, http.StatusBadRequest, "VALIDATION_FAILED", "Некорректное имя категории")
			return
		}
		if errors.Is(err, renamecategory.ErrRevisionConflict) {
			writeError(writer, request, http.StatusConflict, "CONFLICT", "Конфликт ревизии; обновите состояние и повторите действие")
			return
		}
		if err != nil {
			writeError(writer, request, http.StatusInternalServerError, "INTERNAL", "Не удалось переименовать категорию")
			return
		}
		writer.Header().Set("Content-Type", "application/json; charset=utf-8")
		_ = json.NewEncoder(writer).Encode(struct {
			ID       string `json:"id"`
			Name     string `json:"name"`
			Revision int64  `json:"revision"`
		}{result.ID, result.Name, result.Revision})
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
