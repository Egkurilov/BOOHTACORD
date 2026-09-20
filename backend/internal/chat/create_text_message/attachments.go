package createtextmessage

const maxAttachments = 10

func validAttachments(ids []string) bool {
	if len(ids) > maxAttachments {
		return false
	}
	seen := make(map[string]struct{}, len(ids))
	for _, id := range ids {
		if !validUUID(id) {
			return false
		}
		if _, exists := seen[id]; exists {
			return false
		}
		seen[id] = struct{}{}
	}
	return true
}
