package requestid

import (
	"net/http"
	"net/http/httptest"
	"regexp"
	"testing"
)

func TestMiddlewareCreatesServerRequestIDAndExposesIt(t *testing.T) {
	var contextID string
	next := http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		contextID = From(request.Context())
		writer.WriteHeader(http.StatusNoContent)
	})
	request := httptest.NewRequest(http.MethodGet, "/", nil)
	request.Header.Set("X-Request-ID", "client-controlled")
	recorder := httptest.NewRecorder()

	Middleware(next).ServeHTTP(recorder, request)

	if contextID == "client-controlled" || recorder.Header().Get("X-Request-ID") != contextID || !regexp.MustCompile(`^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$`).MatchString(contextID) {
		t.Fatalf("context ID = %q, response ID = %q", contextID, recorder.Header().Get("X-Request-ID"))
	}
}
