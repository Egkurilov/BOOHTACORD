package registration

import (
	"errors"
	"strings"
	"testing"
)

func TestValidateDisplayNameUsesUnicodeCharacterBoundsWithoutTrimming(t *testing.T) {
	for _, test := range []struct {
		name  string
		value string
		valid bool
	}{
		{name: "one character", value: "я", valid: true},
		{name: "sixty four characters", value: strings.Repeat("я", 64), valid: true},
		{name: "empty", value: "", valid: false},
		{name: "sixty five characters", value: strings.Repeat("я", 65), valid: false},
		{name: "spaces remain valid display data", value: "  имя  ", valid: true},
	} {
		err := ValidateDisplayName(test.value)
		if test.valid && err != nil || !test.valid && !errors.Is(err, ErrInvalidDisplayName) {
			t.Errorf("ValidateDisplayName(%q) error = %v", test.value, err)
		}
	}
}
