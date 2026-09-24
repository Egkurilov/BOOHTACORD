package validatementions

import (
	"strings"

	"github.com/google/uuid"
)

const MaxRecipients = 100

// Valid checks the bounded, unique, explicit account identifiers of one message.
// Recipient membership and active status are checked atomically by each store.
func Valid(ids []string, actor string) bool {
	if len(ids) > MaxRecipients {
		return false
	}
	seen := make(map[string]struct{}, len(ids))
	for _, value := range ids {
		parsed, err := uuid.Parse(value)
		if err != nil || len(value) != 36 || parsed == uuid.Nil || strings.EqualFold(value, actor) {
			return false
		}
		canonical := parsed.String()
		if _, exists := seen[canonical]; exists {
			return false
		}
		seen[canonical] = struct{}{}
	}
	return true
}
