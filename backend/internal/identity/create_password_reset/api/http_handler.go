package resetapi

import (
	"context"
	"encoding/json"
	"net/http"
	"net/url"
	"strings"

	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	"voice-platform/backend/internal/identity/create_password_reset"
	"voice-platform/backend/internal/security/request_id"
)

type Creator interface {
	Create(context.Context, createpasswordreset.Input) (createpasswordreset.Result, error)
}

func NewHandler(creator Creator, publicOrigin string) http.Handler {
	return http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		if request.Method != http.MethodPost {
			writer.WriteHeader(http.StatusMethodNotAllowed)
			return
		}
		var body struct {
			AccountID string `json:"account_id"`
		}
		decoder := json.NewDecoder(http.MaxBytesReader(writer, request.Body, 8<<10))
		decoder.DisallowUnknownFields()
		if err := decoder.Decode(&body); err != nil || strings.TrimSpace(body.AccountID) == "" {
			writeError(writer, request, http.StatusBadRequest, "VALIDATION_FAILED", "Некорректный идентификатор аккаунта")
			return
		}
		principal, ok := sessionapi.PrincipalFrom(request.Context())
		if !ok {
			writeError(writer, request, http.StatusInternalServerError, "INTERNAL", "Не удалось создать ссылку сброса")
			return
		}
		result, err := creator.Create(request.Context(), createpasswordreset.Input{AccountID: body.AccountID, ActorID: principal.AccountID})
		if err != nil {
			writeError(writer, request, http.StatusInternalServerError, "INTERNAL", "Не удалось создать ссылку сброса")
			return
		}
		writer.Header().Set("Content-Type", "application/json; charset=utf-8")
		writer.WriteHeader(http.StatusCreated)
		_ = json.NewEncoder(writer).Encode(struct {
			URL       string `json:"url"`
			ExpiresAt string `json:"expires_at"`
		}{
			URL:       strings.TrimSuffix(publicOrigin, "/") + "/reset-password#token=" + url.QueryEscape(result.Token),
			ExpiresAt: result.ExpiresAt.UTC().Format(timeFormat),
		})
	})
}

const timeFormat = "2006-01-02T15:04:05Z07:00"

func writeError(writer http.ResponseWriter, request *http.Request, status int, code, message string) {
	writer.Header().Set("Content-Type", "application/json; charset=utf-8")
	writer.WriteHeader(status)
	_ = json.NewEncoder(writer).Encode(map[string]any{"error": map[string]string{
		"code":       code,
		"message":    message,
		"request_id": requestid.From(request.Context()),
	}})
}
