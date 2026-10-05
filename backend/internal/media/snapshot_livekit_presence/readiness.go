package snapshotlivekitpresence

import (
	"context"
	"github.com/livekit/protocol/auth"
	"github.com/livekit/protocol/livekit"
)

// Ping checks only the private RoomService, without disclosing room or participant data.
func (client Client) Ping(ctx context.Context) error {
	token, err := client.token(auth.VideoGrant{RoomList: true})
	if err != nil {
		return ErrUnavailable
	}
	rooms, err := client.service(token).ListRooms(ctx, &livekit.ListRoomsRequest{})
	if err != nil || rooms == nil {
		return ErrUnavailable
	}
	return nil
}
