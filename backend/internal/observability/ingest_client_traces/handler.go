package ingestclienttraces

import (
	"bytes"
	"context"
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
	return withRelayHealth(http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
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
		sessionID, accountID := diagnosticIdentity(request)
		if claimed := request.Header.Get("X-Telemetry-Session"); claimed != "" && claimed != sessionID {
			observeBatch(request.Context(), batchResult{Fatal: true, Reason: "session_mismatch"})
			writer.WriteHeader(http.StatusBadRequest)
			return
		}
		clean, result := sanitizeBatch(&input, request.Header.Get("X-Client-Platform"), sessionID, accountID)
		if result.Fatal || result.Accepted == 0 {
			observeBatch(request.Context(), result)
			writer.WriteHeader(http.StatusBadRequest)
			return
		}
		verifiedLinks(&input, clean, authorization, accountID)
		encoded, err := proto.Marshal(clean)
		if err != nil {
			writer.WriteHeader(http.StatusServiceUnavailable)
			return
		}
		bounded, cancel := context.WithTimeout(request.Context(), 3*time.Second)
		defer cancel()
		outbound, err := http.NewRequestWithContext(bounded, http.MethodPost, endpoint, bytes.NewReader(encoded))
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
		upstreamBody, readErr := io.ReadAll(io.LimitReader(response.Body, 4097))
		if response.StatusCode != http.StatusOK || readErr != nil || len(upstreamBody) > 4096 {
			writer.WriteHeader(http.StatusServiceUnavailable)
			return
		}
		if len(upstreamBody) > 0 {
			var upstream collectortrace.ExportTraceServiceResponse
			if proto.Unmarshal(upstreamBody, &upstream) != nil {
				writer.WriteHeader(http.StatusServiceUnavailable)
				return
			}
			if partial := upstream.PartialSuccess; partial != nil && partial.RejectedSpans > 0 {
				if partial.RejectedSpans > int64(result.Accepted) {
					writer.WriteHeader(http.StatusServiceUnavailable)
					return
				}
				result.Accepted -= int(partial.RejectedSpans)
				result.Rejected += int(partial.RejectedSpans)
			}
		}
		observeBatch(request.Context(), result)
		accepted(writer, result)
	}))
}
