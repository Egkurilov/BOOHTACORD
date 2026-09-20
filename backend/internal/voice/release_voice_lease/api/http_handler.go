package releasevoiceleaseapi

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"

	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	"voice-platform/backend/internal/security/request_id"
	releasevoicelease "voice-platform/backend/internal/voice/release_voice_lease"
)

type Releaser interface {
	Release(context.Context, releasevoicelease.Input) error
}

func NewHandler(releaser Releaser) http.Handler {
	return http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		if request.Method != http.MethodDelete {
			writer.WriteHeader(http.StatusMethodNotAllowed)
			return
		}
		principal, ok := sessionapi.PrincipalFrom(request.Context())
		if !ok {
			writeError(writer, request, http.StatusInternalServerError, "INTERNAL", "Не удалось выйти из голосового канала")
			return
		}
		err := releaser.Release(request.Context(), releasevoicelease.Input{ActorID: principal.AccountID, LeaseID: request.PathValue("leaseID"), SessionDigest: principal.SessionDigest})
		if errors.Is(err, releasevoicelease.ErrInvalidInput) {
			writeError(writer, request, http.StatusBadRequest, "VALIDATION_FAILED", "Некорректный идентификатор голосового подключения")
			return
		}
		if err != nil {
			writeError(writer, request, http.StatusInternalServerError, "INTERNAL", "Не удалось выйти из голосового канала")
			return
		}
		writer.WriteHeader(http.StatusNoContent)
	})
}

func writeError(writer http.ResponseWriter, request *http.Request, status int, code, message string) {
	writer.Header().Set("Content-Type", "application/json; charset=utf-8")
	writer.WriteHeader(status)
	_ = json.NewEncoder(writer).Encode(map[string]any{"error": map[string]string{"code": code, "message": message, "request_id": requestid.From(request.Context())}})
}
