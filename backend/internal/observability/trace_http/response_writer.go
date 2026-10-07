package tracehttp

import (
	"go.opentelemetry.io/otel/trace"
	"net/http"
)

type statusWriter struct {
	http.ResponseWriter
	code      int
	onUpgrade func(...trace.SpanEndOption)
}

func (writer *statusWriter) Unwrap() http.ResponseWriter { return writer.ResponseWriter }

func (writer *statusWriter) WriteHeader(status int) {
	if status >= 100 && status < 200 && status != http.StatusSwitchingProtocols {
		writer.ResponseWriter.WriteHeader(status)
		return
	}
	if writer.code == 0 {
		writer.code = status
	}
	writer.ResponseWriter.WriteHeader(status)
	if status == http.StatusSwitchingProtocols && writer.onUpgrade != nil {
		writer.onUpgrade()
		writer.onUpgrade = nil
	}
}

func (writer *statusWriter) Write(value []byte) (int, error) {
	if writer.code == 0 {
		writer.code = http.StatusOK
	}
	return writer.ResponseWriter.Write(value)
}

func (writer *statusWriter) FlushError() error {
	if writer.code == 0 {
		writer.WriteHeader(http.StatusOK)
	}
	return http.NewResponseController(writer.ResponseWriter).Flush()
}
func (writer *statusWriter) Flush() { _ = writer.FlushError() }
