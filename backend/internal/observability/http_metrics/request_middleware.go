package httpmetrics

import (
	"net/http"
	"time"
	observehttp "voice-platform/backend/internal/observability/observe_http_requests"
)

func (recorder *Recorder) Middleware(next http.Handler, muxes ...*http.ServeMux) http.Handler {
	var mux *http.ServeMux
	if len(muxes) > 0 {
		mux = muxes[0]
	}
	return http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		started := time.Now()
		route := observehttp.Route(request, mux)
		captured := &responseWriter{ResponseWriter: writer}
		defer func() {
			value := recover()
			status := captured.statusCode()
			if value != nil {
				status = 500
			}
			recorder.routeRequests.ObserveRoute(request, route, status, time.Since(started))
			if value != nil {
				panic(value)
			}
		}()
		next.ServeHTTP(captured, request)
	})
}
