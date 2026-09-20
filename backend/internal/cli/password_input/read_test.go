package passwordinput

import (
	"errors"
	"strings"
	"testing"
)

func TestReadRemovesOnlyPipeLineEnding(t *testing.T) {
	password, err := Read(strings.NewReader("  correct horse battery staple  \r\n"))
	if err != nil || password != "  correct horse battery staple  " {
		t.Fatalf("Read() password = %q, error = %v", password, err)
	}
}

func TestReadRejectsEmptyAndOversizeInput(t *testing.T) {
	for _, value := range []string{"\n", strings.Repeat("x", maxBytes+1)} {
		_, err := Read(strings.NewReader(value))
		if !errors.Is(err, ErrInvalidInput) {
			t.Fatalf("Read(%d bytes) error = %v", len(value), err)
		}
	}
}
