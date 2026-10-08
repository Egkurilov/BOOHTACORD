package watchconnectedparticipants

import (
	"net/http"
	roster "voice-platform/backend/internal/voice/list_connected_participants"
)

func writeInitialFailure(writer http.ResponseWriter, err error) {
	writer.Header().Set("Cache-Control", "no-store")
	status := roster.FailureStatus(err)
	if status == http.StatusServiceUnavailable {
		writer.Header().Set("Retry-After", "1")
	}
	// Stable public message; exact stage stays in bounded internal metrics.
	http.Error(writer, "roster unavailable", status)
}
