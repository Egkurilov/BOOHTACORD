package restorereadonlytextapi

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	action "voice-platform/backend/internal/channel/restore_readonly_text"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	requestid "voice-platform/backend/internal/security/request_id"
)

type Changer interface {
	Restore(context.Context, action.Input) (action.Result, error)
}

func NewHandler(service Changer) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		principal, ok := sessionapi.PrincipalFrom(r.Context())
		if !ok || principal.Role != "ADMINISTRATOR" {
			writeError(w, r, http.StatusForbidden, "FORBIDDEN")
			return
		}
		var body struct {
			ExpectedRevision int64 `json:"expected_revision"`
		}
		decoder := json.NewDecoder(http.MaxBytesReader(w, r.Body, 4096))
		decoder.DisallowUnknownFields()
		if decoder.Decode(&body) != nil || decoder.Decode(&struct{}{}) != io.EOF {
			writeError(w, r, http.StatusBadRequest, "VALIDATION_FAILED")
			return
		}
		result, err := service.Restore(r.Context(), action.Input{ActorID: principal.AccountID, ChannelID: r.PathValue("channelID"), ExpectedRevision: body.ExpectedRevision})
		if errors.Is(err, action.ErrInvalidInput) {
			writeError(w, r, http.StatusBadRequest, "VALIDATION_FAILED")
			return
		}
		if errors.Is(err, action.ErrConflict) {
			writeError(w, r, http.StatusConflict, "REVISION_CONFLICT")
			return
		}
		if err != nil {
			writeError(w, r, http.StatusInternalServerError, "INTERNAL")
			return
		}
		w.Header().Set("Content-Type", "application/json; charset=utf-8")
		w.Header().Set("Cache-Control", "no-store")
		json.NewEncoder(w).Encode(result)
	})
}
func writeError(w http.ResponseWriter, r *http.Request, status int, code string) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(map[string]any{"error": map[string]string{"code": code, "message": "Не удалось изменить состояние архива", "request_id": requestid.From(r.Context())}})
}
