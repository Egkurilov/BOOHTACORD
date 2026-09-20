package listtextmessagespostgres

import (
	"encoding/json"
	"errors"
	"strings"
	"unicode/utf8"

	"github.com/google/uuid"
	listtextmessages "voice-platform/backend/internal/chat/list_text_messages"
)

const maxAttachmentBytes int64 = 25_000_000

var ErrInvalidAttachmentProjection = errors.New("invalid text message attachment projection")

func decodeAttachments(source []byte) ([]listtextmessages.Attachment, error) {
	var attachments []listtextmessages.Attachment
	if err := json.Unmarshal(source, &attachments); err != nil {
		return nil, ErrInvalidAttachmentProjection
	}
	if attachments == nil {
		return nil, ErrInvalidAttachmentProjection
	}
	for _, attachment := range attachments {
		if !validUUID(attachment.ID) || !utf8.ValidString(attachment.OriginalName) || attachment.OriginalName == "" || strings.ContainsRune(attachment.OriginalName, '\x00') || attachment.SizeBytes < 0 || attachment.SizeBytes > maxAttachmentBytes {
			return nil, ErrInvalidAttachmentProjection
		}
	}
	return attachments, nil
}

func validUUID(value string) bool {
	_, err := uuid.Parse(value)
	return err == nil && len(value) == 36
}
