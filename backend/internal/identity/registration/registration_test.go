package registration

import (
	"errors"
	"strings"
	"testing"
)

func TestValidateNormalizesLoginAndPreservesPassword(t *testing.T) {
	input := Input{
		Login:       "Egor_Player",
		DisplayName: "Егор 🎮",
		Password:    "  пароль с пробелами  ",
	}

	result, err := Validate(input)
	if err != nil {
		t.Fatalf("Validate() error = %v", err)
	}
	if result.Login != "egor_player" {
		t.Fatalf("login = %q, want normalized value", result.Login)
	}
	if result.DisplayName != input.DisplayName {
		t.Fatalf("display name = %q, want %q", result.DisplayName, input.DisplayName)
	}
	if result.Password != input.Password {
		t.Fatal("password whitespace must not be trimmed")
	}
}

func TestValidateRejectsInvalidFields(t *testing.T) {
	tests := []struct {
		name  string
		input Input
		want  error
	}{
		{"short login", Input{"ab", "ab", "long enough password"}, ErrInvalidLogin},
		{"non ascii login", Input{"егор", "Егор", "long enough password"}, ErrInvalidLogin},
		{"long display name", Input{"egor", strings.Repeat("x", 65), "long enough password"}, ErrInvalidDisplayName},
		{"short password", Input{"egor", "Егор", "short pass"}, ErrInvalidPassword},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			_, err := Validate(test.input)
			if !errors.Is(err, test.want) {
				t.Fatalf("Validate() error = %v, want %v", err, test.want)
			}
		})
	}
}

func TestValidatePasswordUsesRegistrationPasswordPolicy(t *testing.T) {
	if err := ValidatePassword("short"); !errors.Is(err, ErrInvalidPassword) {
		t.Fatalf("ValidatePassword() error = %v", err)
	}
	if err := ValidatePassword("correct horse battery staple"); err != nil {
		t.Fatalf("ValidatePassword() error = %v", err)
	}
}
