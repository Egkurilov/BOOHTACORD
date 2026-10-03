package categoryapi

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"

	"voice-platform/backend/internal/channel/create_category"
	topologycommand "voice-platform/backend/internal/channel/topology_command"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	"voice-platform/backend/internal/security/request_id"
)

type Creator interface {
	Create(context.Context, createcategory.Input) (createcategory.Result, error)
}

func NewHandler(creator Creator) http.Handler {
	return http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		if request.Method != http.MethodPost {
			writer.WriteHeader(http.StatusMethodNotAllowed)
			return
		}
		principal, ok := sessionapi.PrincipalFrom(request.Context())
		if !ok {
			writeError(writer, request, http.StatusInternalServerError, "INTERNAL", "Не удалось создать категорию")
			return
		}
		var body struct {
			Name            string `json:"name"`
			ClientRequestID string `json:"client_request_id"`
		}
		decoder := json.NewDecoder(http.MaxBytesReader(writer, request.Body, 8<<10))
		decoder.DisallowUnknownFields()
		if err := decoder.Decode(&body); err != nil {
			writeError(writer, request, http.StatusBadRequest, "VALIDATION_FAILED", "Некорректное имя категории")
			return
		}
		category, err := creator.Create(request.Context(), createcategory.Input{ActorID: principal.AccountID, Name: body.Name, ClientRequestID: body.ClientRequestID})
		if errors.Is(err, createcategory.ErrInvalidInput) {
			writeError(writer, request, http.StatusBadRequest, "VALIDATION_FAILED", "Некорректное имя категории")
			return
		}
		if errors.Is(err, topologycommand.ErrKeyReused) {
			writeError(writer, request, http.StatusConflict, "IDEMPOTENCY_KEY_REUSED", "Идентификатор уже использован для другой команды")
			return
		}
		if err != nil {
			writeError(writer, request, http.StatusInternalServerError, "INTERNAL", "Не удалось создать категорию")
			return
		}
		writer.Header().Set("Content-Type", "application/json; charset=utf-8")
		writer.WriteHeader(http.StatusCreated)
		if body.ClientRequestID != "" {
			_ = json.NewEncoder(writer).Encode(map[string]any{"client_request_id": body.ClientRequestID, "topology_revision": category.Revision, "result": map[string]string{"resource_type": "CATEGORY", "resource_id": category.ID, "state": "ACTIVE"}})
			return
		}
		_ = json.NewEncoder(writer).Encode(struct {
			ID       string `json:"id"`
			Name     string `json:"name"`
			Position int    `json:"position"`
			Revision int64  `json:"revision"`
		}{category.ID, category.Name, category.Position, category.Revision})
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
