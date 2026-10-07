package connectsession

import (
	"net/http"
	"time"

	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	eventhub "voice-platform/backend/internal/realtime/event_hub"
)

func NewHandler(authenticator sessionapi.Authenticator, interval time.Duration, now Clock, newID Identifier, observer ConnectionObserver) http.Handler {
	return NewHandlerWithAdmission(authenticator, interval, now, newID, observer, nil, nil)
}

func NewHandlerWithEvents(authenticator sessionapi.Authenticator, interval time.Duration, now Clock, newID Identifier, observer ConnectionObserver, events *eventhub.Hub) http.Handler {
	return NewHandlerWithAdmission(authenticator, interval, now, newID, observer, events, nil)
}
