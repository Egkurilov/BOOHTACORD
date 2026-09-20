package finalizestagedtextattachment

import "github.com/google/uuid"

func newIdentifier() (string, error) {
	identifier, err := uuid.NewRandom()
	return identifier.String(), err
}
