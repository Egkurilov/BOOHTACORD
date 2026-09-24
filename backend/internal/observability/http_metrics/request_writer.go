package httpmetrics

import (
	"bufio"
	"io"
	"net"
	"net/http"
)

type responseWriter struct {
	http.ResponseWriter
	status int
}

func (writer *responseWriter) Unwrap() http.ResponseWriter { return writer.ResponseWriter }

func (writer *responseWriter) WriteHeader(status int) {
	if writer.status == 0 {
		writer.status = status
	}
	writer.ResponseWriter.WriteHeader(status)
}

func (writer *responseWriter) Write(value []byte) (int, error) {
	if writer.status == 0 {
		writer.WriteHeader(http.StatusOK)
	}
	return writer.ResponseWriter.Write(value)
}

func (writer *responseWriter) Flush() {
	if flusher, ok := writer.ResponseWriter.(http.Flusher); ok {
		flusher.Flush()
	}
}

func (writer *responseWriter) Hijack() (net.Conn, *bufio.ReadWriter, error) {
	if hijacker, ok := writer.ResponseWriter.(http.Hijacker); ok {
		return hijacker.Hijack()
	}
	return nil, nil, http.ErrNotSupported
}

func (writer *responseWriter) Push(target string, options *http.PushOptions) error {
	if pusher, ok := writer.ResponseWriter.(http.Pusher); ok {
		return pusher.Push(target, options)
	}
	return http.ErrNotSupported
}

func (writer *responseWriter) ReadFrom(source io.Reader) (int64, error) {
	if writer.status == 0 {
		writer.WriteHeader(http.StatusOK)
	}
	if reader, ok := writer.ResponseWriter.(io.ReaderFrom); ok {
		return reader.ReadFrom(source)
	}
	return io.Copy(writer.ResponseWriter, source)
}

func (writer *responseWriter) statusCode() int {
	if writer.status == 0 {
		return http.StatusOK
	}
	return writer.status
}
