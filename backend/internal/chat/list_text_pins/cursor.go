package listtextpins

import (
	"bytes"
	"encoding/base64"
	"encoding/json"
	"github.com/google/uuid"
	"io"
)

func decodeCursor(encoded, channel string) (*Cursor, error) {
	if encoded == "" {
		return nil, nil
	}
	if len(encoded) > 256 {
		return nil, ErrInvalidInput
	}
	data, err := base64.RawURLEncoding.DecodeString(encoded)
	if err != nil {
		return nil, ErrInvalidInput
	}
	decoder := json.NewDecoder(bytes.NewReader(data))
	decoder.DisallowUnknownFields()
	var cursor Cursor
	if decoder.Decode(&cursor) != nil || decoder.Decode(&struct{}{}) != io.EOF || cursor.ChannelID != channel || cursor.PinnedAt.IsZero() {
		return nil, ErrInvalidInput
	}
	if _, err := uuid.Parse(cursor.MessageID); err != nil {
		return nil, ErrInvalidInput
	}
	return &cursor, nil
}
func encodeCursor(cursor Cursor) string {
	data, _ := json.Marshal(cursor)
	return base64.RawURLEncoding.EncodeToString(data)
}
