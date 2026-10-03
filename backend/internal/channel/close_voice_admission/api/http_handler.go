package closevoiceadmissionapi

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	closevoiceadmission "voice-platform/backend/internal/channel/close_voice_admission"
	topologycommand "voice-platform/backend/internal/channel/topology_command"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	"voice-platform/backend/internal/security/request_id"
)

type Closer interface {
	Close(context.Context, closevoiceadmission.Input) (closevoiceadmission.Result, error)
}

func NewHandler(closer Closer) http.Handler {
	return http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		if request.Method != http.MethodPost {
			writer.WriteHeader(http.StatusMethodNotAllowed)
			return
		}
		principal, ok := sessionapi.PrincipalFrom(request.Context())
		if !ok {
			writeError(writer, request, http.StatusInternalServerError, "INTERNAL", "Не удалось закрыть вход в голосовой канал")
			return
		}
		var body struct {
			ExpectedRevision int64  `json:"expected_revision"`
			ConfirmClose     *bool  `json:"confirm_close"`
			ClientRequestID  string `json:"client_request_id"`
		}
		decoder := json.NewDecoder(http.MaxBytesReader(writer, request.Body, 8<<10))
		decoder.DisallowUnknownFields()
		if err := decoder.Decode(&body); err != nil {
			writeError(writer, request, http.StatusBadRequest, "VALIDATION_FAILED", "Некорректная ревизия топологии")
			return
		}
		if body.ClientRequestID != "" && (body.ConfirmClose == nil || !*body.ConfirmClose) {
			writeError(writer, request, http.StatusBadRequest, "VALIDATION_FAILED", "Требуется подтверждение закрытия")
			return
		}
		result, err := closer.Close(request.Context(), closevoiceadmission.Input{ActorID: principal.AccountID, ChannelID: request.PathValue("channelID"), ExpectedRevision: body.ExpectedRevision, ConfirmClose: body.ConfirmClose != nil && *body.ConfirmClose, ClientRequestID: body.ClientRequestID})
		if errors.Is(err, closevoiceadmission.ErrInvalidInput) {
			writeError(writer, request, http.StatusBadRequest, "VALIDATION_FAILED", "Некорректная ревизия топологии")
			return
		}
		if errors.Is(err, closevoiceadmission.ErrRevisionConflict) {
			writeError(writer, request, http.StatusConflict, "CONFLICT", "Канал нельзя закрыть или состояние устарело; обновите данные")
			return
		}
		if errors.Is(err, topologycommand.ErrKeyReused) {
			writeError(writer, request, http.StatusConflict, "IDEMPOTENCY_KEY_REUSED", "Идентификатор уже использован для другой команды")
			return
		}
		if err != nil {
			writeError(writer, request, http.StatusInternalServerError, "INTERNAL", "Не удалось закрыть вход в голосовой канал")
			return
		}
		writer.Header().Set("Content-Type", "application/json; charset=utf-8")
		if body.ClientRequestID != "" {
			writer.WriteHeader(http.StatusAccepted)
			_ = json.NewEncoder(writer).Encode(map[string]any{"client_request_id": body.ClientRequestID, "topology_revision": result.Revision, "result": map[string]string{"resource_type": "VOICE_CHANNEL", "resource_id": result.ID, "state": "CLOSING"}})
			return
		}
		_ = json.NewEncoder(writer).Encode(struct {
			ID            string `json:"id"`
			Revision      int64  `json:"revision"`
			RevokedLeases int64  `json:"revoked_leases"`
		}{result.ID, result.Revision, result.RevokedLeases})
	})
}

func writeError(writer http.ResponseWriter, request *http.Request, status int, code, message string) {
	writer.Header().Set("Content-Type", "application/json; charset=utf-8")
	writer.WriteHeader(status)
	_ = json.NewEncoder(writer).Encode(map[string]any{"error": map[string]string{"code": code, "message": message, "request_id": requestid.From(request.Context())}})
}
