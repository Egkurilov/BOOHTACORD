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
