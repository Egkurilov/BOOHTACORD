package acquirevoiceleaseapi

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"

	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	"voice-platform/backend/internal/security/request_id"
	acquirevoicelease "voice-platform/backend/internal/voice/acquire_voice_lease"
)

type Acquirer interface {
	Acquire(context.Context, acquirevoicelease.Input) (acquirevoicelease.Result, error)
}

func NewHandler(acquirer Acquirer) http.Handler {
	return http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		if request.Method != http.MethodPost {
			writer.WriteHeader(http.StatusMethodNotAllowed)
			return
		}
		principal, ok := sessionapi.PrincipalFrom(request.Context())
		if !ok {
			writeError(writer, request, http.StatusInternalServerError, "INTERNAL", "Не удалось подготовить подключение к голосу")
			return
		}
		var body struct {
			Transfer bool `json:"transfer"`
		}
		decoder := json.NewDecoder(http.MaxBytesReader(writer, request.Body, 8<<10))
		decoder.DisallowUnknownFields()
		if err := decoder.Decode(&body); err != nil {
			writeError(writer, request, http.StatusBadRequest, "VALIDATION_FAILED", "Некорректный запрос подключения к голосу")
			return
		}
		lease, err := acquirer.Acquire(request.Context(), acquirevoicelease.Input{ActorID: principal.AccountID, ChannelID: request.PathValue("channelID"), SessionDigest: principal.SessionDigest, Transfer: body.Transfer})
		if errors.Is(err, acquirevoicelease.ErrActiveLease) {
			writeActiveLease(writer, request, lease.ExistingChannelID)
			return
		}
		if errors.Is(err, acquirevoicelease.ErrInvalidInput) {
			writeError(writer, request, http.StatusBadRequest, "VALIDATION_FAILED", "Некорректный запрос подключения к голосу")
			return
		}
		if errors.Is(err, acquirevoicelease.ErrSessionUnavailable) {
			writeError(writer, request, http.StatusUnauthorized, "UNAUTHENTICATED", "Сессия больше не активна")
			return
		}
		if errors.Is(err, acquirevoicelease.ErrVoiceChannelUnavailable) {
			writeError(writer, request, http.StatusConflict, "VOICE_CHANNEL_UNAVAILABLE", "Вход в этот голосовой канал недоступен")
			return
		}
		if err != nil {
			writeError(writer, request, http.StatusInternalServerError, "INTERNAL", "Не удалось подготовить подключение к голосу")
			return
		}
		writer.Header().Set("Content-Type", "application/json; charset=utf-8")
		writer.WriteHeader(http.StatusCreated)
		_ = json.NewEncoder(writer).Encode(struct {
			ID          string `json:"id"`
			ChannelID   string `json:"channel_id"`
			Transferred bool   `json:"transferred"`
		}{lease.ID, lease.ChannelID, lease.Transferred})
	})
}

func writeActiveLease(writer http.ResponseWriter, request *http.Request, channelID string) {
	writer.Header().Set("Content-Type", "application/json; charset=utf-8")
	writer.WriteHeader(http.StatusConflict)
	_ = json.NewEncoder(writer).Encode(map[string]any{"error": map[string]string{"code": "ACTIVE_VOICE_LEASE", "message": "Голос уже подключён в другом окне или на другом устройстве", "request_id": requestid.From(request.Context())}, "active_channel_id": channelID})
}

func writeError(writer http.ResponseWriter, request *http.Request, status int, code, message string) {
	writer.Header().Set("Content-Type", "application/json; charset=utf-8")
	writer.WriteHeader(status)
	_ = json.NewEncoder(writer).Encode(map[string]any{"error": map[string]string{"code": code, "message": message, "request_id": requestid.From(request.Context())}})
}
