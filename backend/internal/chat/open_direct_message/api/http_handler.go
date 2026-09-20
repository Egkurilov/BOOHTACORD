package opendirectmessageapi

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"time"

	opendirectmessage "voice-platform/backend/internal/chat/open_direct_message"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	"voice-platform/backend/internal/security/request_id"
)

type Opener interface {
	Open(context.Context, opendirectmessage.Input) (opendirectmessage.Result, error)
}

func NewHandler(opener Opener) http.Handler {
	return http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		principal, ok := sessionapi.PrincipalFrom(request.Context())
		if !ok {
			writeError(writer, request, http.StatusInternalServerError, "INTERNAL", "Не удалось открыть личный диалог")
			return
		}
		var body struct {
			ParticipantID string `json:"participant_id"`
		}
		decoder := json.NewDecoder(http.MaxBytesReader(writer, request.Body, 8<<10))
		decoder.DisallowUnknownFields()
		if err := decoder.Decode(&body); err != nil {
			writeError(writer, request, http.StatusBadRequest, "VALIDATION_FAILED", "Некорректный участник личного диалога")
			return
		}
		result, err := opener.Open(request.Context(), opendirectmessage.Input{ActorID: principal.AccountID, ParticipantID: body.ParticipantID})
		if errors.Is(err, opendirectmessage.ErrInvalidInput) {
			writeError(writer, request, http.StatusBadRequest, "VALIDATION_FAILED", "Некорректный участник личного диалога")
			return
		}
		if errors.Is(err, opendirectmessage.ErrParticipantUnavailable) {
			writeError(writer, request, http.StatusNotFound, "NOT_FOUND", "Участник личного диалога недоступен")
			return
		}
		if err != nil {
			writeError(writer, request, http.StatusInternalServerError, "INTERNAL", "Не удалось открыть личный диалог")
			return
		}
		writer.Header().Set("Content-Type", "application/json; charset=utf-8")
		writer.WriteHeader(http.StatusCreated)
		_ = json.NewEncoder(writer).Encode(struct {
			ID               string    `json:"id"`
			ParticipantOneID string    `json:"participant_one_id"`
			ParticipantTwoID string    `json:"participant_two_id"`
			CreatedAt        time.Time `json:"created_at"`
		}{ID: result.ID, ParticipantOneID: result.ParticipantOneID, ParticipantTwoID: result.ParticipantTwoID, CreatedAt: result.CreatedAt})
	})
}

func writeError(writer http.ResponseWriter, request *http.Request, status int, code, message string) {
	writer.Header().Set("Content-Type", "application/json; charset=utf-8")
	writer.WriteHeader(status)
	_ = json.NewEncoder(writer).Encode(map[string]any{"error": map[string]string{"code": code, "message": message, "request_id": requestid.From(request.Context())}})
}
