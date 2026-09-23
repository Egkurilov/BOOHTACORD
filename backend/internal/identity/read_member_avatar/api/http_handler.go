package readavatarapi

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"strconv"

	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	readmemberavatar "voice-platform/backend/internal/identity/read_member_avatar"
	"voice-platform/backend/internal/security/request_id"
)

var ErrNotFound = readmemberavatar.ErrAvatarNotFound

type Reader interface {
	Read(context.Context, string) ([]byte, error)
}

func NewHandler(reader Reader) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if _, ok := sessionapi.PrincipalFrom(r.Context()); !ok {
			writeError(w, r, http.StatusUnauthorized, "UNAUTHENTICATED", "Требуется вход")
			return
		}
		data, err := reader.Read(r.Context(), r.PathValue("userID"))
		if errors.Is(err, readmemberavatar.ErrAvatarNotFound) {
			writeError(w, r, http.StatusNotFound, "NOT_FOUND", "Изображение не найдено")
			return
		}
		if err != nil {
			writeError(w, r, http.StatusInternalServerError, "INTERNAL", "Не удалось загрузить изображение")
			return
		}
		w.Header().Set("Content-Type", "image/png")
		w.Header().Set("Cache-Control", "private, max-age=60")
		w.Header().Set("X-Content-Type-Options", "nosniff")
		w.Header().Set("Content-Length", strconv.Itoa(len(data)))
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write(data)
	})
}

func writeError(w http.ResponseWriter, r *http.Request, status int, code, message string) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(map[string]any{"error": map[string]string{"code": code, "message": message, "request_id": requestid.From(r.Context())}})
}
