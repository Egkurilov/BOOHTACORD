package readprofileapi

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"

	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	"voice-platform/backend/internal/identity/read_own_profile"
	"voice-platform/backend/internal/security/request_id"
)

type Reader interface {
	Read(context.Context, string) (readownprofile.Profile, error)
}

func NewHandler(reader Reader) http.Handler {
	return http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		if request.Method != http.MethodGet {
			writer.WriteHeader(http.StatusMethodNotAllowed)
			return
		}
		principal, ok := sessionapi.PrincipalFrom(request.Context())
		if !ok {
			writeError(writer, request, http.StatusUnauthorized, "UNAUTHENTICATED", "Требуется вход")
			return
		}
		profile, err := reader.Read(request.Context(), principal.AccountID)
		if errors.Is(err, readownprofile.ErrProfileNotFound) {
			writeError(writer, request, http.StatusNotFound, "NOT_FOUND", "Профиль не найден")
			return
		}
		if err != nil {
			writeError(writer, request, http.StatusInternalServerError, "INTERNAL", "Не удалось загрузить профиль")
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
