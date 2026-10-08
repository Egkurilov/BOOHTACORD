package listconnectedparticipants

import (
	"context"
	"errors"
	"net/http"
	presence "voice-platform/backend/internal/media/snapshot_livekit_presence"
)

// OperationFailure carries bounded internal attribution without dependency text.
type OperationFailure struct {
	Stage string
	Cause error
}

// FailureStage is suitable for request-correlated internal trace attributes.
func FailureStage(err error) string {
	var failure OperationFailure
	if !errors.As(err, &failure) {
		return "internal"
	}
	stage := failure.Stage
	switch stage {
	case "visibility_initial", "visibility_recheck":
	case "presence_snapshot":
		stage = "presence_" + presence.FailureStage(failure.Cause)
	default:
		return "internal"
	}
	if errors.Is(err, context.DeadlineExceeded) {
		return stage + "_timeout"
	}
	if errors.Is(err, context.Canceled) {
		return stage + "_canceled"
	}
	return stage
}

func (failure OperationFailure) Error() string { return "voice roster operation unavailable" }
func (failure OperationFailure) Unwrap() error { return failure.Cause }

func FailureStatus(err error) int {
	var failure OperationFailure
	if errors.As(err, &failure) {
		if failure.Stage == "presence_snapshot" {
			switch presence.FailureStage(failure.Cause) {
			case "validation", "token":
				return http.StatusInternalServerError
			}
		}
		return http.StatusServiceUnavailable
	}
	if errors.Is(err, ErrPresenceUnavailable) || errors.Is(err, context.DeadlineExceeded) {
		return http.StatusServiceUnavailable
	}
	return http.StatusInternalServerError
}
