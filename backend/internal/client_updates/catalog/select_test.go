package clientupdates

import (
	"strings"
	"testing"
)

func TestSelectReturnsExactPolicy(t *testing.T) {
	catalog, err := Parse(strings.NewReader(validCatalog), nil)
	if err != nil {
		t.Fatal(err)
	}
	policy, ok := catalog.Select(Selector{Platform: "web", Distribution: "browser", Channel: "stable", Arch: "any"})
	if !ok || policy.Target == nil || policy.Target.ReleaseID != "web-7" {
		t.Fatalf("unexpected policy: %#v", policy)
	}
	if policy.ApplicationFamily != "boohtacord" || policy.CatalogRevision != 7 {
		t.Fatalf("missing envelope: %#v", policy)
	}
}

func TestValidateSelectorRejectsUnsupportedPair(t *testing.T) {
	selector := Selector{Platform: "web", Distribution: "direct", Channel: "stable", Arch: "any"}
	if err := selector.Validate(); err == nil {
		t.Fatal("expected invalid distribution")
	}
}
