package httpmetrics

import (
	"bufio"
	"io"
	"net"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestMiddlewarePreservesUpgradeResponseWriterInterfaces(t *testing.T) {
	recorder := New()
	wrapped := recorder.Middleware(http.HandlerFunc(func(writer http.ResponseWriter, _ *http.Request) {
		if _, ok := writer.(http.Hijacker); !ok {
			t.Fatal("wrapped writer lost Hijacker")
		}
		if _, ok := writer.(http.Flusher); !ok {
			t.Fatal("wrapped writer lost Flusher")
		}
		if _, ok := writer.(http.Pusher); !ok {
			t.Fatal("wrapped writer lost Pusher")
		}
		if _, ok := writer.(io.ReaderFrom); !ok {
			t.Fatal("wrapped writer lost ReaderFrom")
		}
		if _, ok := writer.(interface{ Unwrap() http.ResponseWriter }); !ok {
			t.Fatal("wrapped writer lost Unwrap")
		}
	}))
	wrapped.ServeHTTP(&transportWriter{ResponseRecorder: httptest.NewRecorder()}, httptest.NewRequest(http.MethodGet, "/rtc", nil))
}

type transportWriter struct{ *httptest.ResponseRecorder }

func (writer *transportWriter) Flush() {}

func (writer *transportWriter) Hijack() (net.Conn, *bufio.ReadWriter, error) { return nil, nil, nil }

func (writer *transportWriter) Push(string, *http.PushOptions) error { return nil }

func (writer *transportWriter) ReadFrom(source io.Reader) (int64, error) {
	return io.Copy(writer.ResponseRecorder, source)
}
