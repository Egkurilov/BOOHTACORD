package guildsettings

import (
	"strings"
	"testing"
)

func TestNameValidationPreservesInteriorAndCase(t *testing.T) {
	input := Input{SetName: true, Name: "  Моя  Гильдия  ", ExpectedRevision: 1}
	got, err := Validate(input)
	if err != nil || got.Name != "Моя  Гильдия" {
		t.Fatal("name normalization changed interior")
	}
	for _, name := range []string{"", "  ", "a\nb", "a\tb", "a\x00b", strings.Repeat("я", 81)} {
		input.Name = name
		if _, err := Validate(input); err == nil {
			t.Fatal("invalid name accepted")
		}
	}
	input.Name = strings.Repeat("я", 80)
	if _, err := Validate(input); err != nil {
		t.Fatal("80 Unicode codepoints rejected")
	}
}
func TestWelcomePatchPresenceAndRevision(t *testing.T) {
	for _, input := range []Input{{ExpectedRevision: 1}, {SetWelcome: true, ExpectedRevision: 0}, {SetWelcome: true, WelcomeChannelID: "bad", ExpectedRevision: 1}} {
		if _, err := Validate(input); err == nil {
			t.Fatal("invalid settings accepted")
		}
	}
	if _, err := Validate(Input{SetWelcome: true, ExpectedRevision: 1}); err != nil {
		t.Fatal("disable rejected")
	}
}
