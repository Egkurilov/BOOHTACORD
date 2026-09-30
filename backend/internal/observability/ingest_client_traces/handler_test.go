package ingestclienttraces

import (
	"bytes"
	"io"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	collectortrace "go.opentelemetry.io/proto/otlp/collector/trace/v1"
	commonpb "go.opentelemetry.io/proto/otlp/common/v1"
	resourcepb "go.opentelemetry.io/proto/otlp/resource/v1"
	tracepb "go.opentelemetry.io/proto/otlp/trace/v1"
	"google.golang.org/protobuf/proto"
)

func TestHandlerForwardsOnlySafeClientSpanFields(t *testing.T) {
	var forwarded collectortrace.ExportTraceServiceRequest
	var authorization string
	upstream := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		authorization = request.Header.Get("Authorization")
		body, err := io.ReadAll(request.Body)
		if err != nil || proto.Unmarshal(body, &forwarded) != nil {
			writer.WriteHeader(http.StatusBadRequest)
			return
		}
		writer.WriteHeader(http.StatusOK)
	}))
	defer upstream.Close()
	now := uint64(time.Now().UnixNano())
	span := &tracepb.Span{
		TraceId: bytes.Repeat([]byte{1}, 16), SpanId: bytes.Repeat([]byte{2}, 8), Name: "api.request",
		StartTimeUnixNano: now - 1000000, EndTimeUnixNano: now,
		Attributes: []*commonpb.KeyValue{{Key: "dm.body", Value: &commonpb.AnyValue{Value: &commonpb.AnyValue_StringValue{StringValue: "private-message"}}}},
	}
	input := &collectortrace.ExportTraceServiceRequest{ResourceSpans: []*tracepb.ResourceSpans{{
		Resource:   &resourcepb.Resource{Attributes: []*commonpb.KeyValue{{Key: "service.name", Value: &commonpb.AnyValue{Value: &commonpb.AnyValue_StringValue{StringValue: "private-service"}}}}},
		ScopeSpans: []*tracepb.ScopeSpans{{Spans: []*tracepb.Span{span}}},
	}}}
	encoded, err := proto.Marshal(input)
	if err != nil {
		t.Fatal(err)
	}
	request := httptest.NewRequest(http.MethodPost, "/api/v1/telemetry/traces", bytes.NewReader(encoded))
	request.Header.Set("Content-Type", "application/x-protobuf")
	request.Header.Set("X-Client-Platform", "web")
	request.Header.Set("Authorization", "attacker-header")
	response := httptest.NewRecorder()
	NewHandler(upstream.URL, "Basic server-secret", upstream.Client()).ServeHTTP(response, request)
	if response.Code != http.StatusAccepted || authorization != "Basic server-secret" {
		t.Fatalf("status=%d auth=%q", response.Code, authorization)
	}
	got := forwarded.ResourceSpans[0].ScopeSpans[0].Spans[0]
	if got.Name != "api.request" || len(got.Attributes) != 0 || len(got.Events) != 0 || len(got.Links) != 0 {
		t.Fatalf("unsafe forwarded span: %+v", got)
	}
	if forwarded.ResourceSpans[0].Resource.Attributes[0].Value.GetStringValue() != "boohtacord-web" {
		t.Fatal("resource service name was not replaced")
	}
}

func TestHandlerRejectsUnknownOperations(t *testing.T) {
	span := &tracepb.Span{TraceId: bytes.Repeat([]byte{1}, 16), SpanId: bytes.Repeat([]byte{2}, 8), Name: "private-message"}
	encoded, _ := proto.Marshal(&collectortrace.ExportTraceServiceRequest{ResourceSpans: []*tracepb.ResourceSpans{{ScopeSpans: []*tracepb.ScopeSpans{{Spans: []*tracepb.Span{span}}}}}})
	request := httptest.NewRequest(http.MethodPost, "/api/v1/telemetry/traces", bytes.NewReader(encoded))
	request.Header.Set("Content-Type", "application/x-protobuf")
	request.Header.Set("X-Client-Platform", "web")
	response := httptest.NewRecorder()
	NewHandler("https://collector.example.test/v1/traces", "Basic secret", nil).ServeHTTP(response, request)
	if response.Code != http.StatusBadRequest {
		t.Fatalf("status=%d", response.Code)
	}
}
