package adminapi

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"

	"voice-platform/backend/internal/identity/admin_account"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	"voice-platform/backend/internal/security/request_id"
)

type Updater interface {
	Update(context.Context, adminaccount.Input) (adminaccount.Account, error)
}

func NewHandler(updater Updater) http.Handler {
	return http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		if request.Method != http.MethodPatch {
			writer.WriteHeader(http.StatusMethodNotAllowed)
			return
		}
		principal, ok := sessionapi.PrincipalFrom(request.Context())
		if !ok {
			writeError(writer, request, http.StatusInternalServerError, "INTERNAL", "Не удалось изменить аккаунт")
			return
		}
		var body struct {
			Role    adminaccount.Role `json:"role"`
			Blocked *bool             `json:"blocked"`
		}
		decoder := json.NewDecoder(http.MaxBytesReader(writer, request.Body, 8<<10))
		decoder.DisallowUnknownFields()
		if err := decoder.Decode(&body); err != nil || body.Blocked == nil {
			writeError(writer, request, http.StatusBadRequest, "VALIDATION_FAILED", "Некорректные данные аккаунта")
			return
		}
		account, err := updater.Update(request.Context(), adminaccount.Input{ActorID: principal.AccountID, AccountID: request.PathValue("accountID"), Role: body.Role, Blocked: *body.Blocked})
		if errors.Is(err, adminaccount.ErrInvalidInput) {
			writeError(writer, request, http.StatusBadRequest, "VALIDATION_FAILED", "Некорректные данные аккаунта")
			return
		}
		if errors.Is(err, adminaccount.ErrUpdateDenied) {
			writeError(writer, request, http.StatusConflict, "CONFLICT", "Нельзя изменить последнего активного администратора")
			return
		}
		if err != nil {
			writeError(writer, request, http.StatusInternalServerError, "INTERNAL", "Не удалось изменить аккаунт")
			return
		}
		writer.Header().Set("Content-Type", "application/json; charset=utf-8")
		_ = json.NewEncoder(writer).Encode(struct {
			ID      string `json:"id"`
			Role    string `json:"role"`
			Blocked bool   `json:"blocked"`
		}{account.ID, string(account.Role), account.Blocked})
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
