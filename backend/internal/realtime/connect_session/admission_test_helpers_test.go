package connectsession

import (
	"testing"
	"time"

	"voice-platform/backend/internal/realtime/admit_connection"
)

func waitForQuotaToDrain(t *testing.T, quota *admitconnection.Limiter) {
	t.Helper()
	deadline := time.Now().Add(time.Second)
	for quota.Stats().ActiveConnections != 0 && time.Now().Before(deadline) {
		time.Sleep(time.Millisecond)
	}
	if active := quota.Stats().ActiveConnections; active != 0 {
		t.Fatalf("active connection quota = %d after socket close, want 0", active)
	}
}
