package snapshotlivekitpresence

import (
	"errors"
)

type unavailableError struct{ stage string }

func (failure unavailableError) Error() string { return ErrUnavailable.Error() }
func (failure unavailableError) Unwrap() error { return ErrUnavailable }

func unavailable(stage string) error { return unavailableError{stage: stage} }

// FailureStage returns a fixed internal stage, never dependency text or IDs.
func FailureStage(err error) string {
	var failure unavailableError
	if !errors.As(err, &failure) {
		return "snapshot"
	}
	switch failure.stage {
	case "validation", "token", "room_list", "participants":
		return failure.stage
	default:
		return "snapshot"
	}
}
