package publish_screen_descriptor

import "errors"

var (
	ErrInvalid     = errors.New("invalid screen profile descriptor")
	ErrDenied      = errors.New("screen profile update denied")
	ErrStale       = errors.New("screen profile operation is stale")
	ErrConflict    = errors.New("screen profile operation conflicts")
	ErrUnavailable = errors.New("screen profile update unavailable")
)
