package ingestclienttraces

import tracepb "go.opentelemetry.io/proto/otlp/trace/v1"

// Only static lifecycle event names survive the client relay; attributes never do.
func safeClientEvents(span *tracepb.Span) []*tracepb.Span_Event {
	prefix := "app.client." + span.Name + "."
	output := make([]*tracepb.Span_Event, 0, 2)
	for _, event := range span.Events {
		if event == nil || len(output) >= 4 || event.TimeUnixNano < span.StartTimeUnixNano || event.TimeUnixNano > span.EndTimeUnixNano {
			continue
		}
		switch event.Name {
		case prefix + "started", prefix + "completed", prefix + "failed":
			output = append(output, &tracepb.Span_Event{TimeUnixNano: event.TimeUnixNano, Name: event.Name})
		}
	}
	return output
}
