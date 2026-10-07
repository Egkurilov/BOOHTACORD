package publishscreendescriptorapi

import (
	"errors"
	"net/http"
	"strconv"

	publishdescriptor "voice-platform/backend/internal/media/publish_screen_descriptor"
)

func writeOperationFailure(writer http.ResponseWriter, err error) {
	switch {
	case errors.Is(err, publishdescriptor.ErrInvalid):
		writeError(writer, http.StatusBadRequest, "VALIDATION_FAILED")
	case errors.Is(err, publishdescriptor.ErrDenied):
		writeError(writer, http.StatusNotFound, "LEASE_NOT_AVAILABLE")
	case errors.Is(err, publishdescriptor.ErrStale), errors.Is(err, publishdescriptor.ErrConflict):
		writeError(writer, http.StatusConflict, "OPERATION_STALE")
	default:
		writeError(writer, http.StatusServiceUnavailable, "SCREEN_PROFILE_UNAVAILABLE")
	}
}

func writeError(writer http.ResponseWriter, status int, code string) {
	writer.Header().Set("Content-Type", "application/json; charset=utf-8")
	writer.WriteHeader(status)
	_, _ = writer.Write([]byte(`{"error":{"code":"` + code + `"}}`))
}

func uintString(value uint64) string { return strconv.FormatUint(value, 10) }
