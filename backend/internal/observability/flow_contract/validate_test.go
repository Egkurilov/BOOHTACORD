package flowcontract

import (
	"encoding/json"
	"os"
	"testing"
)

func TestSharedPrivacyAndBoundaryFixtures(t *testing.T) {
	data, err := os.ReadFile("../../../../contracts/telemetry-flow-v1.fixtures.json")
	if err != nil {
		t.Fatal(err)
	}
	var fixtures []struct {
		Key   string
		Value any
		Valid bool
	}
	if err := json.Unmarshal(data, &fixtures); err != nil {
		t.Fatal(err)
	}
	for _, fixture := range fixtures {
		if Valid(fixture.Key, fixture.Value) != fixture.Valid {
			t.Errorf("%s: %v", fixture.Key, fixture.Value)
		}
	}
}

func TestSchemaDeclaresFieldPresenceAndStringBudgets(t *testing.T) {
	data, err := os.ReadFile("../../../../contracts/telemetry-flow-v1.json")
	if err != nil {
		t.Fatal(err)
	}
	var schema struct {
		Limits struct {
			Spans, Attributes, Events, Links int
			LinkAttributes                   int `json:"linkAttributes"`
			MaxBatchBytes                    int `json:"maxBatchBytes"`
			SpanNameBytes                    int `json:"spanNameBytes"`
			AttributeKeyBytes                int `json:"attributeKeyBytes"`
			AttributeStringBytes             int `json:"attributeStringBytes"`
		} `json:"limits"`
		Fields map[string]struct {
			Owner     string `json:"owner"`
			Required  *bool  `json:"required"`
			Type      string `json:"type"`
			MinLength int    `json:"minLength"`
			MaxLength int    `json:"maxLength"`
		} `json:"fields"`
	}
	if err := json.Unmarshal(data, &schema); err != nil {
		t.Fatal(err)
	}
	if schema.Limits.Spans != MaxSpans || schema.Limits.Attributes != MaxAttributes || schema.Limits.Events != MaxEvents || schema.Limits.Links != MaxLinks || schema.Limits.LinkAttributes != MaxLinkAttributes || schema.Limits.MaxBatchBytes != MaxBatchBytes || schema.Limits.SpanNameBytes != MaxSpanNameBytes || schema.Limits.AttributeKeyBytes != MaxAttributeKeyBytes || schema.Limits.AttributeStringBytes != MaxAttributeStringBytes {
		t.Fatalf("generated relay limits differ from schema: %+v", schema.Limits)
	}
	for key, field := range schema.Fields {
		if field.Owner == "" || field.Required == nil {
			t.Errorf("%s is missing its owner or explicit requiredness", key)
		}
		if (field.Type == "id" || field.Type == "version" || field.Type == "enum") && field.MaxLength == 0 {
			t.Errorf("%s has no declared string length bound", key)
		}
	}
	for _, key := range []string{"app.schema.version", "session.id", "app.visit.id", "app.flow.id", "app.flow.name", "app.flow.stage", "app.flow.record", "app.flow.outcome", "app.flow.attempt"} {
		if field, ok := schema.Fields[key]; !ok || field.Required == nil || !*field.Required {
			t.Errorf("%s must be explicitly required for a versioned action", key)
		}
	}
	if schema.Fields["app.provenance"].Required == nil || *schema.Fields["app.provenance"].Required {
		t.Fatal("server-owned provenance must not be a client-required field")
	}
}
