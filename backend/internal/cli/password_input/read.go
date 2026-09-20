package passwordinput

import (
	"errors"
	"io"
	"strings"
)

const maxBytes = 1024

var ErrInvalidInput = errors.New("invalid password input")

func Read(reader io.Reader) (string, error) {
	value, err := io.ReadAll(io.LimitReader(reader, maxBytes+1))
	if err != nil || len(value) > maxBytes {
		return "", ErrInvalidInput
	}
	password := strings.TrimSuffix(strings.TrimSuffix(string(value), "\n"), "\r")
	if password == "" {
		return "", ErrInvalidInput
	}
	return password, nil
}
