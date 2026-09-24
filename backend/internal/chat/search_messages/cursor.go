package searchmessages

import (
	"encoding/base64"
	"encoding/json"
	"time"
)

type Cursor struct {
	CreatedAt time.Time
	Kind, ID  string
}

type cursorPayload struct {
	Version   int    `json:"v"`
	CreatedAt string `json:"t"`
	Kind      string `json:"k"`
	ID        string `json:"i"`
}

func encodeCursor(message Message) (string, error) {
	if !validUUID(message.ID) || (message.Kind != KindChannel && message.Kind != KindDirectMessage) || message.CreatedAt.IsZero() {
		return "", ErrInvalidInput
	}
	payload, err := json.Marshal(cursorPayload{Version: 1, CreatedAt: message.CreatedAt.UTC().Format(time.RFC3339Nano), Kind: message.Kind, ID: message.ID})
	if err != nil {
		return "", err
	}
	return base64.RawURLEncoding.EncodeToString(payload), nil
}

func decodeCursor(value string) (*Cursor, error) {
	if len(value) > 512 {
		return nil, ErrInvalidInput
	}
	data, err := base64.RawURLEncoding.DecodeString(value)
	if err != nil {
		return nil, ErrInvalidInput
	}
	var payload cursorPayload
	if err = json.Unmarshal(data, &payload); err != nil || payload.Version != 1 || !validUUID(payload.ID) || (payload.Kind != KindChannel && payload.Kind != KindDirectMessage) {
		return nil, ErrInvalidInput
	}
	createdAt, err := time.Parse(time.RFC3339Nano, payload.CreatedAt)
	if err != nil || createdAt.IsZero() {
		return nil, ErrInvalidInput
	}
	return &Cursor{CreatedAt: createdAt.UTC(), Kind: payload.Kind, ID: payload.ID}, nil
}

func validUUID(value string) bool {
	if len(value) != 36 {
		return false
	}
	for index, character := range value {
		if index == 8 || index == 13 || index == 18 || index == 23 {
			if character != '-' {
				return false
			}
			continue
		}
		if !((character >= '0' && character <= '9') || (character >= 'a' && character <= 'f') || (character >= 'A' && character <= 'F')) {
			return false
		}
	}
	return true
}
