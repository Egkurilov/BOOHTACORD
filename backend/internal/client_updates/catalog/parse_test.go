package clientupdates

import (
	"strings"
	"testing"
)

const validCatalog = `{
  "schema_version":1,"catalog_revision":7,"application_family":"boohtacord",
  "entries":[{"platform":"web","distribution":"browser","channel":"stable","arch":"any","state":"published",
  "target":{"release_id":"web-7","release_order":7,"version":"1.0.0","native_build":null,"priority":"normal",
  "published_at":"2026-10-02T09:00:00Z","summary":"Update","release_notes_url":null,
  "requirements":{"supported_arches":["any"]},"action":{"kind":"reload","url":null}}}]}`

func TestParseValidCatalog(t *testing.T) {
	catalog, err := Parse(strings.NewReader(validCatalog), []string{"github.com"})
	if err != nil {
		t.Fatal(err)
	}
	if catalog.Revision != 7 || len(catalog.Entries) != 1 {
		t.Fatalf("unexpected catalog: %#v", catalog)
	}
}

func TestParseRejectsUnknownField(t *testing.T) {
	_, err := Parse(strings.NewReader(strings.Replace(validCatalog, `"schema_version":1`, `"schema_version":1,"secret":"x"`, 1)), nil)
	if err == nil {
		t.Fatal("expected unknown field rejection")
	}
}

func TestParseRejectsUnsafeURL(t *testing.T) {
	unsafe := strings.Replace(validCatalog, `"release_notes_url":null`, `"release_notes_url":"javascript:alert(1)"`, 1)
	if _, err := Parse(strings.NewReader(unsafe), nil); err == nil {
		t.Fatal("expected unsafe URL rejection")
	}
}

func TestParseRejectsOversizedCatalog(t *testing.T) {
	if _, err := Parse(strings.NewReader(strings.Repeat("x", maxCatalogBytes+1)), nil); err == nil {
		t.Fatal("expected size rejection")
	}
}
