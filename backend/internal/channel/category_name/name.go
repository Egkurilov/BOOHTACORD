package categoryname

import (
	"errors"
	"unicode/utf8"
)

var ErrInvalidName = errors.New("invalid category name")

func Validate(value string) error {
	if !utf8.ValidString(value) || utf8.RuneCountInString(value) < 1 || utf8.RuneCountInString(value) > 80 {
		return ErrInvalidName
	}
	return nil
}
