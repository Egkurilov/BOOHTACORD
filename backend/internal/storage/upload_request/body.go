package uploadrequest

import (
	"context"
	"errors"
	"io"
	"net/http"
	"sync"
	"time"
)

var ErrReadTimeout = errors.New("upload body read deadline exceeded")

func TimedOut(ctx context.Context) bool { return errors.Is(context.Cause(ctx), ErrReadTimeout) }

func WithLimits(request *http.Request, maximum, idle time.Duration) (*http.Request, func()) {
	ctx, cancel := context.WithCancelCause(request.Context())
	body := &boundedBody{source: request.Body, cancel: cancel, idle: idle}
	body.timer = time.AfterFunc(idle, func() { body.expire() })
	maximumTimer := time.AfterFunc(maximum, func() { body.expire() })
	request.Body = body
	return request.WithContext(ctx), func() { maximumTimer.Stop(); body.timer.Stop(); cancel(nil) }
}

type boundedBody struct {
	source  io.ReadCloser
	cancel  context.CancelCauseFunc
	mutex   sync.Mutex
	timer   *time.Timer
	idle    time.Duration
	expired bool
}

func (body *boundedBody) Read(buffer []byte) (int, error) {
	count, err := body.source.Read(buffer)
	body.mutex.Lock()
	defer body.mutex.Unlock()
	if body.expired {
		return count, ErrReadTimeout
	}
	if count > 0 {
		body.timer.Reset(body.idle)
	}
	return count, err
}

func (body *boundedBody) expire() {
	body.mutex.Lock()
	if body.expired {
		body.mutex.Unlock()
		return
	}
	body.expired = true
	body.mutex.Unlock()
	body.cancel(ErrReadTimeout)
	_ = body.source.Close()
}

func (body *boundedBody) Close() error { body.timer.Stop(); return body.source.Close() }
