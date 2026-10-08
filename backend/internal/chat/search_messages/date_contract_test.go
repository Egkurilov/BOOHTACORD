package searchmessages

import (
	"encoding/json"
	"os"
	"regexp"
	"testing"
)

func TestDateBoundContractPatternAcceptsClientFractionalInstants(t *testing.T) {
	data, err := os.ReadFile("../../../../contracts/openapi.yaml")
	if err != nil {
		t.Fatal(err)
	}
	var contract struct {
		Paths map[string]struct {
			Get struct {
				Parameters []struct {
					Name   string `json:"name"`
					Schema struct {
						Pattern string `json:"pattern"`
					} `json:"schema"`
				} `json:"parameters"`
			} `json:"get"`
		} `json:"paths"`
	}
	if err = json.Unmarshal(data, &contract); err != nil {
		t.Fatal(err)
	}
	found := 0
	for _, parameter := range contract.Paths["/api/v1/search/messages"].Get.Parameters {
		if parameter.Name != "created_from" && parameter.Name != "created_before" {
			continue
		}
		found++
		pattern, err := regexp.Compile(parameter.Schema.Pattern)
		if err != nil {
			t.Fatal(err)
		}
		for _, input := range []string{"2026-10-08T00:00:00.000Z", "2026-10-08T00:00:00.123456+03:00", "2026-10-08T00:00:00Z"} {
			if !pattern.MatchString(input) {
				t.Fatalf("contract rejects browser/backend-supported instant %q", input)
			}
			if _, err := parseInstant(input); err != nil {
				t.Fatalf("backend rejected contract instant: %v", err)
			}
		}
		for _, input := range []string{"2026-10-08", "2026-10-08T00:00:00.1234567Z", "2026-10-08T00:00:00+24:00"} {
			if pattern.MatchString(input) {
				t.Fatalf("contract accepted malformed instant %q", input)
			}
		}
	}
	if found != 2 {
		t.Fatalf("date parameters=%d", found)
	}
}
