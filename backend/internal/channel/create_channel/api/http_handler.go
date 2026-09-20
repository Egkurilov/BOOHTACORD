package channelapi

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"

	"voice-platform/backend/internal/channel/create_channel"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	"voice-platform/backend/internal/security/request_id"
)

type Creator interface {
	Create(context.Context, createchannel.Input) (createchannel.Result, error)
}

func NewHandler(creator Creator) http.Handler {
	return http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		if request.Method != http.MethodPost {
			writer.WriteHeader(http.StatusMethodNotAllowed)
			return
		}
		principal, ok := sessionapi.PrincipalFrom(request.Context())
		if !ok {
			writeError(writer, request, http.StatusInternalServerError, "INTERNAL", "Не удалось создать канал")
			return
		}
		var body struct {
			Name string             `json:"name"`
			Kind createchannel.Kind `json:"kind"`
		}
		decoder := json.NewDecoder(http.MaxBytesReader(writer, request.Body, 8<<10))
		decoder.DisallowUnknownFields()
		if err := decoder.Decode(&body); err != nil {
			writeError(writer, request, http.StatusBadRequest, "VALIDATION_FAILED", "Некорректные данные канала")
			return
		}
		channel, err := creator.Create(request.Context(), createchannel.Input{ActorID: principal.AccountID, CategoryID: request.PathValue("categoryID"), Name: body.Name, Kind: body.Kind})
		if errors.Is(err, createchannel.ErrInvalidInput) {
			writeError(writer, request, http.StatusBadRequest, "VALIDATION_FAILED", "Некорректные данные канала")
			return
		}
		if errors.Is(err, createchannel.ErrCategoryNotFound) {
			writeError(writer, request, http.StatusNotFound, "NOT_FOUND", "Категория не найдена")
			return
		}
		if err != nil {
			writeError(writer, request, http.StatusInternalServerError, "INTERNAL", "Не удалось создать канал")
			return
		}
		writer.Header().Set("Content-Type", "application/json; charset=utf-8")
		writer.WriteHeader(http.StatusCreated)
		_ = json.NewEncoder(writer).Encode(struct {
			ID         string `json:"id"`
			CategoryID string `json:"category_id"`
			Name       string `json:"name"`
			Kind       string `json:"kind"`
			Position   int    `json:"position"`
			Revision   int64  `json:"revision"`
		}{channel.ID, channel.CategoryID, channel.Name, string(channel.Kind), channel.Position, channel.Revision})
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
