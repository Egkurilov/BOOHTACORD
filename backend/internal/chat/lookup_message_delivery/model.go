package delivery

import "errors"

var ErrUnavailable = errors.New("delivery conversation unavailable")

type Input struct {
	ActorID, ConversationID, ClientMessageID string
	Direct                                   bool
}
