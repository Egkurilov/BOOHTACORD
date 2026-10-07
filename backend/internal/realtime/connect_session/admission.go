package connectsession

import (
	"crypto/sha256"
	"net/http"
)

type Admission interface {
	TryAcquire(accountID string, sessionDigest [sha256.Size]byte) (release func(), allowed bool)
}

func rejectAdmission(writer http.ResponseWriter, observer ConnectionObserver) {
	if metrics, ok := observer.(interface{ ObserveRealtimeConnectionRejected() }); ok {
		metrics.ObserveRealtimeConnectionRejected()
	}
	writer.Header().Set("Retry-After", "1")
	writer.Header().Set("Content-Type", "application/json; charset=utf-8")
	writer.WriteHeader(http.StatusTooManyRequests)
	_, _ = writer.Write([]byte(`{"error":{"code":"REALTIME_LIMITED","message":"Слишком много realtime-соединений"}}`))
}
