package password

import (
	"crypto/rand"
	"crypto/subtle"
	"encoding/base64"
	"errors"
	"fmt"
	"io"
	"strings"

	"golang.org/x/crypto/argon2"
)

const (
	memoryKiB   uint32 = 19456
	iterations  uint32 = 2
	parallelism uint8  = 1
	saltLength         = 16
	keyLength   uint32 = 32
)

var ErrInvalidHash = errors.New("invalid password hash")
var dummyHash string
var argonSlots = make(chan struct{}, 4)

func init() {
	salt := []byte("boohtacord-login-dummy-salt")
	key := argon2.IDKey([]byte("unmatchable-dummy-password"), salt, iterations, memoryKiB, parallelism, keyLength)
	dummyHash = fmt.Sprintf("$argon2id$v=19$m=%d,t=%d,p=%d$%s$%s", memoryKiB, iterations, parallelism,
		base64.RawStdEncoding.EncodeToString(salt), base64.RawStdEncoding.EncodeToString(key))
}

func Hash(plainText string) (string, error) {
	argonSlots <- struct{}{}
	defer func() { <-argonSlots }()
	salt := make([]byte, saltLength)
	if _, err := io.ReadFull(rand.Reader, salt); err != nil {
		return "", fmt.Errorf("generate password salt: %w", err)
	}

	derivedKey := argon2.IDKey([]byte(plainText), salt, iterations, memoryKiB, parallelism, keyLength)
	return fmt.Sprintf(
		"$argon2id$v=19$m=%d,t=%d,p=%d$%s$%s",
		memoryKiB,
		iterations,
		parallelism,
		base64.RawStdEncoding.EncodeToString(salt),
		base64.RawStdEncoding.EncodeToString(derivedKey),
	), nil
}

func Verify(plainText, encoded string) (bool, error) {
	argonSlots <- struct{}{}
	defer func() { <-argonSlots }()
	salt, storedKey, err := decode(encoded)
	if err != nil {
		return false, err
	}

	candidate := argon2.IDKey([]byte(plainText), salt, iterations, memoryKiB, parallelism, keyLength)
	return subtle.ConstantTimeCompare(candidate, storedKey) == 1, nil
}

// VerifyUnknown performs the same Argon2id work as a normal verification for
// an account that does not exist. The result is intentionally discarded.
func VerifyUnknown(plainText string) {
	_, _ = Verify(plainText, dummyHash)
}

func decode(encoded string) ([]byte, []byte, error) {
	parts := strings.Split(encoded, "$")
	wantParameters := fmt.Sprintf("m=%d,t=%d,p=%d", memoryKiB, iterations, parallelism)
	if len(parts) != 6 || parts[0] != "" || parts[1] != "argon2id" || parts[2] != "v=19" || parts[3] != wantParameters {
		return nil, nil, ErrInvalidHash
	}

	salt, saltErr := base64.RawStdEncoding.DecodeString(parts[4])
	key, keyErr := base64.RawStdEncoding.DecodeString(parts[5])
	if saltErr != nil || keyErr != nil || len(salt) != saltLength || len(key) != int(keyLength) {
		return nil, nil, ErrInvalidHash
	}
	return salt, key, nil
}
