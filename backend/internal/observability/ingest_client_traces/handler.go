package ingestclienttraces

import (
	"bytes"
	"io"
	"net/http"
	"net/url"
	"strings"
	"time"

	collectortrace "go.opentelemetry.io/proto/otlp/collector/trace/v1"
	"google.golang.org/protobuf/proto"
)

const maxBodyBytes = 256 * 1024

// NewHandler accepts a bounded OTLP batch from an authenticated client and strips all user-controlled metadata.
func NewHandler(endpoint, authorization string, client *http.Client) http.Handler {
	if client == nil {
		client = &http.Client{Timeout: 3 * time.Second}
	}
	destination, err := url.Parse(endpoint)
	configured := err == nil && destination != nil && (destination.Scheme == "https" || destination.Scheme == "http") && destination.Host != "" && destination.User == nil && authorization != ""
	return http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		if !configured {
			writer.WriteHeader(http.StatusServiceUnavailable)
			return
		}
		if !strings.HasPrefix(request.Header.Get("Content-Type"), "application/x-protobuf") {
			writer.WriteHeader(http.StatusUnsupportedMediaType)
			return
		}
		body, err := io.ReadAll(http.MaxBytesReader(writer, request.Body, maxBodyBytes))
		if err != nil {
			writer.WriteHeader(http.StatusRequestEntityTooLarge)
			return
		}
		var input collectortrace.ExportTraceServiceRequest
		if proto.Unmarshal(body, &input) != nil {
			writer.WriteHeader(http.StatusBadRequest)
			return
		}
		clean, ok := sanitize(&input, request.Header.Get("X-Client-Platform"))
		if !ok {
			writer.WriteHeader(http.StatusBadRequest)
			return
		}
		encoded, err := proto.Marshal(clean)
		if err != nil {
			writer.WriteHeader(http.StatusServiceUnavailable)
			return
		}
		outbound, err := http.NewRequestWithContext(request.Context(), http.MethodPost, endpoint, bytes.NewReader(encoded))
		if err != nil {
			writer.WriteHeader(http.StatusServiceUnavailable)
			return
		}
		outbound.Header.Set("Content-Type", "application/x-protobuf")
		outbound.Header.Set("Authorization", authorization)
		response, err := client.Do(outbound)
		if err != nil {
			writer.WriteHeader(http.StatusServiceUnavailable)
			return
		}
		defer response.Body.Close()
		_, _ = io.Copy(io.Discard, io.LimitReader(response.Body, 4096))
		if response.StatusCode != http.StatusOK {
			writer.WriteHeader(http.StatusServiceUnavailable)
			return
		}
		writer.WriteHeader(http.StatusAccepted)
	})
}
