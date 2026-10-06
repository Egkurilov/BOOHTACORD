package bindflow

import (
	"context"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/trace"
	"net/http"
	"strconv"
	contract "voice-platform/backend/internal/observability/flow_contract"
)

type key struct{}
type Context struct {
	VisitID, FlowID, Name, MediaID string
	Attempt                        int
}

func From(ctx context.Context) (Context, bool) { v, ok := ctx.Value(key{}).(Context); return v, ok }
func Bind(ctx context.Context, header http.Header, sessionID string) context.Context {
	visit, flow, name := header.Get("X-App-Visit"), header.Get("X-App-Flow"), header.Get("X-App-Flow-Name")
	attempt, err := strconv.Atoi(header.Get("X-App-Attempt"))
	if header.Get("X-Telemetry-Session") != sessionID || !contract.ValidID(sessionID) || !contract.ValidID(visit) || !contract.ValidID(flow) || !contract.Valid("app.flow.name", name) || err != nil || !contract.Valid("app.flow.attempt", attempt) {
		return ctx
	}
	media := header.Get("X-App-Media-Session")
	if !contract.ValidID(media) {
		media = ""
	}
	value := Context{visit, flow, name, media, attempt}
	trace.SpanFromContext(ctx).SetAttributes(value.Attributes()...)
	return context.WithValue(ctx, key{}, value)
}
func (value Context) Attributes() []attribute.KeyValue {
	attrs := []attribute.KeyValue{attribute.Int("app.schema.version", 1), attribute.String("app.visit.id", value.VisitID),
		attribute.String("app.flow.id", value.FlowID), attribute.String("app.flow.name", value.Name),
		attribute.Int("app.flow.attempt", value.Attempt), attribute.String("app.provenance", "server_confirmed")}
	if value.MediaID != "" {
		attrs = append(attrs, attribute.String("app.media.session.id", value.MediaID))
	}
	return attrs
}
