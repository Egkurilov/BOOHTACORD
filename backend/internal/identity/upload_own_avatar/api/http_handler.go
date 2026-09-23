package uploadavatarapi

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"mime"
	"net/http"

	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	uploadownavatar "voice-platform/backend/internal/identity/upload_own_avatar"
	"voice-platform/backend/internal/security/request_id"
)

const maxAvatarUpload = 2 << 20

type Uploader interface {
	Upload(context.Context, uploadownavatar.Input) (string, error)
}
type Deleter interface {
	Delete(context.Context, string) error
}

func NewUploadHandler(uploader Uploader) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		principal, ok := sessionapi.PrincipalFrom(r.Context())
		if !ok {
			writeError(w, r, http.StatusUnauthorized, "UNAUTHENTICATED", "Требуется вход")
			return
		}
		mediaType, _, mediaErr := mime.ParseMediaType(r.Header.Get("Content-Type"))
		if mediaErr != nil || (mediaType != "image/png" && mediaType != "image/jpeg") {
			writeError(w, r, http.StatusBadRequest, "VALIDATION_FAILED", "Некорректное изображение")
			return
		}
		data, err := io.ReadAll(http.MaxBytesReader(w, r.Body, maxAvatarUpload))
		if err != nil {
			writeError(w, r, http.StatusBadRequest, "VALIDATION_FAILED", "Некорректное изображение")
			return
		}
		_, err = uploader.Upload(r.Context(), uploadownavatar.Input{AccountID: principal.AccountID, ContentType: r.Header.Get("Content-Type"), Data: data})
		if errors.Is(err, uploadownavatar.ErrInvalidImage) {
			writeError(w, r, http.StatusBadRequest, "VALIDATION_FAILED", "Некорректное изображение")
			return
		}
		if errors.Is(err, uploadownavatar.ErrProfileUnavailable) {
			writeError(w, r, http.StatusNotFound, "NOT_FOUND", "Профиль недоступен")
			return
		}
		if err != nil {
			writeError(w, r, http.StatusInternalServerError, "INTERNAL", "Не удалось сохранить изображение")
			return
		}
		w.WriteHeader(http.StatusNoContent)
	})
}

func NewDeleteHandler(deleter Deleter) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		principal, ok := sessionapi.PrincipalFrom(r.Context())
		if !ok {
			writeError(w, r, http.StatusUnauthorized, "UNAUTHENTICATED", "Требуется вход")
			return
		}
		if err := deleter.Delete(r.Context(), principal.AccountID); err != nil {
			if errors.Is(err, uploadownavatar.ErrProfileUnavailable) {
				writeError(w, r, http.StatusNotFound, "NOT_FOUND", "Профиль недоступен")
				return
			}
			writeError(w, r, http.StatusInternalServerError, "INTERNAL", "Не удалось удалить изображение")
			return
		}
		w.WriteHeader(http.StatusNoContent)
	})
}

func writeError(w http.ResponseWriter, r *http.Request, status int, code, message string) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(map[string]any{"error": map[string]string{"code": code, "message": message, "request_id": requestid.From(r.Context())}})
}
