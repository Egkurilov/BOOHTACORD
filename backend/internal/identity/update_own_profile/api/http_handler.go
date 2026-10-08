package updateprofileapi

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"net/http"

	"voice-platform/backend/internal/identity/authenticate_session/api"
	"voice-platform/backend/internal/identity/update_own_profile"
	"voice-platform/backend/internal/security/request_id"
)

type Updater interface {
	Update(context.Context, updateownprofile.Input) (updateownprofile.Profile, error)
}

func NewHandler(updater Updater) http.Handler {
	return http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		if request.Method != http.MethodPatch {
			writer.WriteHeader(http.StatusMethodNotAllowed)
			return
		}
		principal, ok := sessionapi.PrincipalFrom(request.Context())
		if !ok {
			writeError(writer, request, http.StatusUnauthorized, "UNAUTHENTICATED", "Требуется вход")
			return
		}
		var body struct {
			DisplayName string `json:"display_name"`
		}
		decoder := json.NewDecoder(http.MaxBytesReader(writer, request.Body, 8<<10))
		decoder.DisallowUnknownFields()
		if err := decoder.Decode(&body); err != nil || decoder.Decode(&struct{}{}) != io.EOF {
			writeError(writer, request, http.StatusBadRequest, "VALIDATION_FAILED", "Некорректное имя профиля")
			return
		}
		profile, err := updater.Update(request.Context(), updateownprofile.Input{AccountID: principal.AccountID, DisplayName: body.DisplayName})
		if errors.Is(err, updateownprofile.ErrInvalidDisplayName) {
			writeError(writer, request, http.StatusBadRequest, "VALIDATION_FAILED", "Имя должно содержать от 1 до 64 символов")
			return
		}
		if errors.Is(err, updateownprofile.ErrProfileNotFound) {
			writeError(writer, request, http.StatusNotFound, "NOT_FOUND", "Профиль не найден")
			return
		}
		if err != nil {
			writeError(writer, request, http.StatusInternalServerError, "INTERNAL", "Не удалось сохранить профиль")
			return
		}
		writer.Header().Set("Content-Type", "application/json; charset=utf-8")
		_ = json.NewEncoder(writer).Encode(profileResponse{AccountID: profile.AccountID, Login: profile.Login, DisplayName: profile.DisplayName, Role: profile.Role, AvatarURL: profile.AvatarURL, Revision: profile.Revision})
	})
}

type profileResponse struct {
	AccountID   string `json:"account_id"`
	Login       string `json:"login"`
	DisplayName string `json:"display_name"`
	Role        string `json:"role"`
	AvatarURL   string `json:"avatar_url,omitempty"`
	Revision    int64  `json:"profile_revision"`
}

func writeError(writer http.ResponseWriter, request *http.Request, status int, code, message string) {
	writer.Header().Set("Content-Type", "application/json; charset=utf-8")
	writer.WriteHeader(status)
	_ = json.NewEncoder(writer).Encode(map[string]any{"error": map[string]string{
		"code": code, "message": message, "request_id": requestid.From(request.Context()),
	}})
}
