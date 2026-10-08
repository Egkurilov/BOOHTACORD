package snapshotlivekitpresence

import (
	"context"
	"errors"
	"net/http"
	"time"
	classify "voice-platform/backend/internal/media/classify_room_service_failure"
)

type durationObserver interface {
	ObserveSFURoomServiceDuration(string, string, time.Duration)
}

func observeDuration(observer CallObserver, method string, started time.Time, response *http.Response, err error) {
	if classes, ok := observer.(interface{ ObserveSFURoomServiceFailureClass(string, string, string) }); ok {
		class, status := classify.Classify(response, err)
		classes.ObserveSFURoomServiceFailureClass(method, class, status)
	}
	if duration, ok := observer.(durationObserver); ok {
		outcome := "success"
		switch {
		case errors.Is(err, context.Canceled):
			outcome = "canceled"
		case errors.Is(err, context.DeadlineExceeded):
			outcome = "timeout"
		case response != nil && response.StatusCode == http.StatusTooManyRequests:
			outcome = "overload"
		case err != nil || response == nil:
			outcome = "transport_error"
		case response.StatusCode >= 400:
			outcome = "http_error"
		}
		duration.ObserveSFURoomServiceDuration(method, outcome, time.Since(started))
	}
}
