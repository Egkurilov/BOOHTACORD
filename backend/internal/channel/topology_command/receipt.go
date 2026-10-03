package topologycommand

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"

	"github.com/google/uuid"
)

const (
	OperationCategoryCreate = "CATEGORY_CREATE"
	OperationTextCreate     = "TEXT_CHANNEL_CREATE"
	OperationVoiceCreate    = "VOICE_CHANNEL_CREATE"
	OperationTextArchive    = "TEXT_CHANNEL_ARCHIVE"
	OperationVoiceClose     = "VOICE_CHANNEL_CLOSE"
	OperationCategoryDelete = "CATEGORY_DELETE"
)

var (
	ErrInvalidClientRequestID = errors.New("invalid client request id")
	ErrNotFound               = errors.New("topology command not found")
	ErrKeyReused              = errors.New("idempotency key reused")
)

type Intent struct {
	Operation, ResourceID, ParentID, Kind, Name string
	Confirmation                                bool
}

type Receipt struct {
	ClientRequestID  string `json:"client_request_id"`
	Operation        string `json:"operation,omitempty"`
	IntentHash       string `json:"-"`
	ResourceID       string `json:"resource_id"`
	ResourceType     string `json:"resource_type"`
	ResultState      string `json:"state"`
	TopologyRevision int64  `json:"topology_revision"`
	ResponseStatus   int    `json:"-"`
}

func ValidateClientRequestID(value string) error {
	id, err := uuid.Parse(value)
	if err != nil || id.Version() != 4 || id.String() != value {
		return ErrInvalidClientRequestID
	}
	return nil
}

func Fingerprint(intent Intent) string {
	payload, _ := json.Marshal(intent)
	digest := sha256.Sum256(payload)
	return hex.EncodeToString(digest[:])
}
