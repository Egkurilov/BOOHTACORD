package authorizelivekitsignalapi

import (
	"context"
	"errors"
	"net/http"

	authorizelivekitsignal "voice-platform/backend/internal/media/authorize_livekit_signal"
)

type Admitter interface {
	Admit(context.Context, string) error
}

func NewHandler(admitter Admitter) http.Handler {
	return http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		if request.Method != http.MethodGet {
			writer.WriteHeader(http.StatusMethodNotAllowed)
			return
		}
		if err := admitter.Admit(request.Context(), request.Header.Get("X-Forwarded-Uri")); err != nil {
			if errors.Is(err, authorizelivekitsignal.ErrDenied) {
				writer.WriteHeader(http.StatusForbidden)
				return
			}
			writer.WriteHeader(http.StatusServiceUnavailable)
			return
		}
		writer.WriteHeader(http.StatusNoContent)
	})
}
