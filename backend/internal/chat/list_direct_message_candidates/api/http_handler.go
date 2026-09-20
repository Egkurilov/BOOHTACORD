package listdirectmessagecandidatesapi

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"strconv"

	listdirectmessagecandidates "voice-platform/backend/internal/chat/list_direct_message_candidates"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	"voice-platform/backend/internal/security/request_id"
)

type Lister interface {
	List(context.Context, listdirectmessagecandidates.Input) (listdirectmessagecandidates.Result, error)
}

func NewHandler(lister Lister) http.Handler {
	return http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		principal, ok := sessionapi.PrincipalFrom(request.Context())
		if !ok {
			writeError(writer, request, http.StatusInternalServerError, "INTERNAL", "Не удалось загрузить участников личных диалогов")
			return
		}
		limit := 50
		if rawLimit := request.URL.Query().Get("limit"); rawLimit != "" {
			parsed, err := strconv.Atoi(rawLimit)
			if err != nil {
				writeError(writer, request, http.StatusBadRequest, "VALIDATION_FAILED", "Некорректный размер списка участников")
				return
			}
			limit = parsed
		}
		result, err := lister.List(request.Context(), listdirectmessagecandidates.Input{ActorID: principal.AccountID, After: request.URL.Query().Get("after"), Limit: limit})
		if errors.Is(err, listdirectmessagecandidates.ErrInvalidInput) {
			writeError(writer, request, http.StatusBadRequest, "VALIDATION_FAILED", "Некорректный список участников")
			return
		}
		if err != nil {
			writeError(writer, request, http.StatusInternalServerError, "INTERNAL", "Не удалось загрузить участников личных диалогов")
			return
		}
		writer.Header().Set("Content-Type", "application/json; charset=utf-8")
		_ = json.NewEncoder(writer).Encode(response{Candidates: candidates(result.Candidates), NextAfter: result.NextAfter})
	})
}

type response struct {
	Candidates []candidate `json:"candidates"`
	NextAfter  string      `json:"next_after,omitempty"`
}
type candidate struct {
	ID          string `json:"id"`
	DisplayName string `json:"display_name"`
}

func candidates(source []listdirectmessagecandidates.Candidate) []candidate {
	result := make([]candidate, 0, len(source))
	for _, value := range source {
		result = append(result, candidate{ID: value.ID, DisplayName: value.DisplayName})
	}
	return result
}
func writeError(writer http.ResponseWriter, request *http.Request, status int, code, message string) {
	writer.Header().Set("Content-Type", "application/json; charset=utf-8")
	writer.WriteHeader(status)
	_ = json.NewEncoder(writer).Encode(map[string]any{"error": map[string]string{"code": code, "message": message, "request_id": requestid.From(request.Context())}})
}
