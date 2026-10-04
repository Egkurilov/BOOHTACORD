package registrationwelcome

import (
	"bytes"
	"errors"
	"testing"
)

type brokenReader struct{}

func (brokenReader) Read([]byte) (int, error) { return 0, errors.New("rng unavailable") }
func TestPhraseSelectionHasStableIdentifiersAndNoAccountText(t *testing.T) {
	if len(phrases) < 8 || len(phrases) > 12 {
		t.Fatal("wrong phrase count")
	}
	seen := map[string]bool{}
	for _, phrase := range phrases {
		if phrase.ID == "" || phrase.Body == "" || seen[phrase.ID] {
			t.Fatal("invalid phrase")
		}
		seen[phrase.ID] = true
	}
	selected, err := SelectPhrase(bytes.NewReader(make([]byte, 32)))
	if err != nil || selected != phrases[0] {
		t.Fatal("injected selection failed")
	}
	if _, err := SelectPhrase(brokenReader{}); err == nil {
		t.Fatal("random failure hidden")
	}
}
