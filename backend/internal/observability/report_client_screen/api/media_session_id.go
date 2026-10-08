package reportscreenapi

import (
	"errors"
	"strings"

	"github.com/google/uuid"
)

func canonicalMediaSessionID(leaseID string) (string, error) {
	parsed, err := uuid.Parse(leaseID)
	if err != nil || parsed == uuid.Nil || len(leaseID) != 36 || parsed.String() != strings.ToLower(leaseID) {
		return "", errors.New("invalid voice lease identifier")
	}
	return strings.ReplaceAll(parsed.String(), "-", ""), nil
}
