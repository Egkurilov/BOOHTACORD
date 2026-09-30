package correlatesession

import (
	"crypto/sha256"
	"encoding/hex"

	"go.opentelemetry.io/otel/attribute"
)

// Attributes correlates private traces using an authenticated account and login.
// The derived session ID is not a cookie, token digest or authentication input.
// These attributes belong on spans only, never on metric labels or resources.
func Attributes(accountID string, digest [sha256.Size]byte) []attribute.KeyValue {
	if accountID == "" {
		return nil
	}
	attributes := []attribute.KeyValue{attribute.String("user.id", accountID)}
	if digest == ([sha256.Size]byte{}) {
		return attributes
	}
	hash := sha256.New()
	hash.Write([]byte("boohtacord/otel/session/v1\x00" + accountID + "\x00"))
	hash.Write(digest[:])
	id := hex.EncodeToString(hash.Sum(nil)[:16])
	return append(attributes, attribute.String("session.id", id))
}

// NamedAttributes adds the authenticated profile's display name for private
// diagnostics. Group and filter by the stable account ID, even after renaming.
// Names must never become metric labels, resources or access-log fields.
func NamedAttributes(accountID string, digest [sha256.Size]byte, displayName string) []attribute.KeyValue {
	attrs := Attributes(accountID, digest)
	if accountID == "" || displayName == "" {
		return attrs
	}
	return append(attrs, attribute.String("user.name", displayName),
		attribute.String("user.label", displayName+" · "+accountID))
}
