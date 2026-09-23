package registration

import (
	"errors"
	"strings"
	"unicode/utf8"
)

var (
	ErrInvalidLogin       = errors.New("invalid login")
	ErrInvalidDisplayName = errors.New("invalid display name")
	ErrInvalidPassword    = errors.New("invalid password")
)

type Input struct {
	Login       string
	DisplayName string
	Password    string
}

type Validated struct {
	Login       string
	DisplayName string
	Password    string
}

func Validate(input Input) (Validated, error) {
	login, err := NormalizeLogin(input.Login)
	if err != nil {
		return Validated{}, err
	}
	if err := ValidateDisplayName(input.DisplayName); err != nil {
		return Validated{}, err
	}
	if err := ValidatePassword(input.Password); err != nil {
		return Validated{}, err
	}

	return Validated{
		Login:       login,
		DisplayName: input.DisplayName,
		Password:    input.Password,
	}, nil
}

func ValidateDisplayName(value string) error {
	if !validUnicodeLength(value, 1, 64) {
		return ErrInvalidDisplayName
	}
	return nil
}

func ValidatePassword(value string) error {
	if !validUnicodeLength(value, 12, 128) {
		return ErrInvalidPassword
	}
	return nil
}

func NormalizeLogin(value string) (string, error) {
	login := strings.ToLower(value)
	if !validLogin(login) {
		return "", ErrInvalidLogin
	}
	return login, nil
}

func validLogin(login string) bool {
	if len(login) < 3 || len(login) > 32 {
		return false
	}

	for _, character := range login {
		if (character < 'a' || character > 'z') &&
			(character < '0' || character > '9') &&
			character != '_' && character != '.' && character != '-' {
			return false
		}
	}
	return true
}

func validUnicodeLength(value string, minimum, maximum int) bool {
	if !utf8.ValidString(value) {
		return false
	}
	length := utf8.RuneCountInString(value)
	return length >= minimum && length <= maximum
}
