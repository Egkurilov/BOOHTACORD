package connectsession

import (
	"context"
	"errors"
	"go.opentelemetry.io/otel/trace"
	flowstage "voice-platform/backend/internal/observability/flow_stage"
)

var errHandshakeWrite = errors.New("handshake write failed")
var errHandshakeSession = errors.New("handshake session rejected")

// Complete readiness while the persistent stream is still open. The deferred
// fallback covers early write failures without emitting a second terminal.
func beginHandshake(ctx context.Context) func(error) {
	_, span := flowstage.Begin(ctx, "realtime.connect.ready", "ready", trace.WithSpanKind(trace.SpanKindServer))
	ended := false
	return func(err error) {
		if ended {
			return
		}
		ended = true
		flowstage.End(span, err, flowstage.Reject(errHandshakeSession, "permission_denied"))
	}
}
