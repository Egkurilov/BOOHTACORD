package managevoicetimeoutapi

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"time"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	timeout "voice-platform/backend/internal/voice/manage_voice_timeout"
)

type Manager interface {
	Set(context.Context, timeout.Input) (timeout.State, error)
	Clear(context.Context, timeout.Input) (timeout.State, error)
	Read(context.Context, timeout.Input) (timeout.State, error)
}

func NewHandler(manager Manager) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		principal, ok := sessionapi.PrincipalFrom(r.Context())
		if !ok {
			writeError(w, r, timeout.ErrUnauthenticated)
			return
		}
		ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
		defer cancel()
		in := timeout.Input{ActorID: principal.AccountID, TargetID: r.PathValue("accountID"), SessionDigest: principal.SessionDigest}
		var state timeout.State
		var err error
		status := http.StatusOK
		switch r.Method {
		case http.MethodPut:
			var body struct {
				ExpiresAt time.Time `json:"expires_at"`
				Reason    string    `json:"reason_code"`
			}
			decoder := json.NewDecoder(http.MaxBytesReader(w, r.Body, 8<<10))
			decoder.DisallowUnknownFields()
			if err = decoder.Decode(&body); err != nil {
				writeError(w, r, timeout.ErrInvalidInput)
				return
			}
			var trailing any
			if err = decoder.Decode(&trailing); !errors.Is(err, io.EOF) {
				writeError(w, r, timeout.ErrInvalidInput)
				return
			}
			in.ExpiresAt = body.ExpiresAt
			in.Reason = body.Reason
			state, err = manager.Set(ctx, in)
			status = http.StatusAccepted
		case http.MethodDelete:
			state, err = manager.Clear(ctx, in)
		case http.MethodGet:
			state, err = manager.Read(ctx, in)
		default:
			w.WriteHeader(http.StatusMethodNotAllowed)
			return
		}
		if err != nil {
			writeError(w, r, err)
			return
		}
		w.Header().Set("Content-Type", "application/json; charset=utf-8")
		w.Header().Set("Cache-Control", "no-store")
		w.WriteHeader(status)
		_ = json.NewEncoder(w).Encode(state)
	})
}
