package topologycommandapi

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"

	topologycommand "voice-platform/backend/internal/channel/topology_command"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	"voice-platform/backend/internal/security/request_id"
)

type Reader interface {
	ReadOwn(context.Context, string, string) (topologycommand.Receipt, error)
}

func NewHandler(reader Reader) http.Handler {
	return http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		principal, ok := sessionapi.PrincipalFrom(request.Context())
		if !ok {
			writeError(writer, request, http.StatusInternalServerError, "INTERNAL", "Не удалось получить результат команды")
			return
		}
		clientRequestID := request.PathValue("clientRequestID")
		if topologycommand.ValidateClientRequestID(clientRequestID) != nil {
			writeError(writer, request, http.StatusBadRequest, "VALIDATION_FAILED", "Некорректный идентификатор команды")
			return
		}
		receipt, err := reader.ReadOwn(request.Context(), principal.AccountID, clientRequestID)
		if errors.Is(err, topologycommand.ErrNotFound) {
			writeError(writer, request, http.StatusNotFound, "COMMAND_NOT_FOUND", "Результат команды не найден")
			return
		}
		if err != nil {
			writeError(writer, request, http.StatusInternalServerError, "INTERNAL", "Не удалось получить результат команды")
			return
		}
		writer.Header().Set("Cache-Control", "no-store")
		writer.Header().Set("Content-Type", "application/json; charset=utf-8")
		_ = json.NewEncoder(writer).Encode(map[string]any{"client_request_id": receipt.ClientRequestID, "topology_revision": receipt.TopologyRevision, "result": receipt})
	})
}

func writeError(writer http.ResponseWriter, request *http.Request, status int, code, message string) {
	writer.Header().Set("Content-Type", "application/json; charset=utf-8")
	writer.WriteHeader(status)
	_ = json.NewEncoder(writer).Encode(map[string]any{"error": map[string]string{"code": code, "message": message, "request_id": requestid.From(request.Context())}})
}
