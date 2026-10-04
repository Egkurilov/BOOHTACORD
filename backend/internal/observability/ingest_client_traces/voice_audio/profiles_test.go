package voiceaudio

import (
	"encoding/json"
	"os"
	"reflect"
	"testing"
)

func TestProfileWhitelistMatchesCanonicalContract(t *testing.T) {
	data, err := os.ReadFile("../../../../../contracts/voice-audio-profile.json")
	if err != nil {
		t.Fatal(err)
	}
	var contract struct {
		Profiles []struct {
			ID string `json:"id"`
		} `json:"profiles"`
	}
	if err := json.Unmarshal(data, &contract); err != nil {
		t.Fatal(err)
	}
	expected := map[string]bool{}
	for _, profile := range contract.Profiles {
		expected[profile.ID] = true
	}
	if !reflect.DeepEqual(expected, Profiles) {
		t.Fatalf("profile drift: %v", Profiles)
	}
}
