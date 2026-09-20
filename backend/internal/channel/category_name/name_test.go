package categoryname

import (
	"errors"
	"strings"
	"testing"
)

func TestValidateAcceptsUnicodeNameFromOneToEightyRunes(t *testing.T) {
	for _, value := range []string{"Общее", strings.Repeat("🎮", 80)} {
		if err := Validate(value); err != nil {
			t.Fatalf("Validate(%q) error = %v", value, err)
		}
	}
}

func TestValidateRejectsEmptyOversizeAndInvalidUTF8(t *testing.T) {
	for _, value := range []string{"", strings.Repeat("x", 81), string([]byte{0xff})} {
		if err := Validate(value); !errors.Is(err, ErrInvalidName) {
			t.Fatalf("Validate(%q) error = %v", value, err)
		}
	}
}
