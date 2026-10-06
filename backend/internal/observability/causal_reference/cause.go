package causalreference

import (
	"context"
	"encoding/hex"
	"encoding/json"
	"go.opentelemetry.io/otel/trace"
	bindflow "voice-platform/backend/internal/observability/bind_flow"
	contract "voice-platform/backend/internal/observability/flow_contract"
)

type Cause struct {
	TraceID string `json:"trace_id"`
	SpanID  string `json:"span_id"`
	FlowID  string `json:"flow_id,omitempty"`
	Version int    `json:"version"`
}

func (c Cause) Valid() bool {
	traceID, err := trace.TraceIDFromHex(c.TraceID)
	if err != nil || !traceID.IsValid() {
		return false
	}
	spanID, err := trace.SpanIDFromHex(c.SpanID)
	return err == nil && spanID.IsValid() && c.Version == 1 && (c.FlowID == "" || contract.ValidID(c.FlowID))
}
func From(ctx context.Context) Cause {
	span := trace.SpanContextFromContext(ctx)
	if !span.IsValid() {
		return Cause{}
	}
	flow, _ := bindflow.From(ctx)
	return Cause{span.TraceID().String(), span.SpanID().String(), flow.FlowID, 1}
}
func (c Cause) Link() trace.Link {
	tid, _ := trace.TraceIDFromHex(c.TraceID)
	sid, _ := trace.SpanIDFromHex(c.SpanID)
	return trace.Link{SpanContext: trace.NewSpanContext(trace.SpanContextConfig{TraceID: tid, SpanID: sid})}
}
func (c Cause) Bytes() []byte {
	if !c.Valid() {
		return nil
	}
	body, _ := json.Marshal(c)
	return body
}
func Decode(body []byte) Cause {
	var c Cause
	if len(body) > 256 || json.Unmarshal(body, &c) != nil || !c.Valid() {
		return Cause{}
	}
	return c
}
func (c Cause) IDs() ([]byte, []byte) {
	t, _ := hex.DecodeString(c.TraceID)
	s, _ := hex.DecodeString(c.SpanID)
	return t, s
}
