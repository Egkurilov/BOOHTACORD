package origincheck

import (
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"

	"voice-platform/backend/internal/security/request_id"
)

type Middleware func(http.Handler) http.Handler

func New(value string) (Middleware, error) {
	origin, err := url.ParseRequestURI(value)
	if err != nil || (origin.Scheme != "http" && origin.Scheme != "https") || origin.Host == "" || origin.Path != "" || origin.RawQuery != "" || origin.Fragment != "" {
		return nil, fmt.Errorf("invalid public origin")
	}
	expected := origin.Scheme + "://" + origin.Host
	if value != expected {
		return nil, fmt.Errorf("public origin must not contain a path, query, fragment, or trailing slash")
	}

	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
			if mutatesState(request.Method) && !(request.Method == http.MethodPost && request.URL.Path == "/internal/livekit/roster") && request.Header.Get("Origin") != expected {
				writeForbidden(writer, request)
				return
			}
			next.ServeHTTP(writer, request)
		})
	}, nil
}

func mutatesState(method string) bool {
	return method == http.MethodPost || method == http.MethodPut || method == http.MethodPatch || method == http.MethodDelete
}

func writeForbidden(writer http.ResponseWriter, request *http.Request) {
	writer.Header().Set("Content-Type", "application/json; charset=utf-8")
	writer.WriteHeader(http.StatusForbidden)
	_ = json.NewEncoder(writer).Encode(map[string]any{"error": map[string]string{
		"code":       "FORBIDDEN",
		"message":    "Недопустимый Origin",
		"request_id": requestid.From(request.Context()),
	}})
}
