package snapshotlivekitpresence

import (
	"context"

	"github.com/google/uuid"
	"github.com/livekit/protocol/auth"
	"github.com/livekit/protocol/livekit"
)

// CountRoomParticipants asks the private RoomService for one exact voice room.
// A successful, empty ListRooms response is the only authoritative absent-room proof.
func (client Client) CountRoomParticipants(ctx context.Context, channelID string) (int, error) {
	if uuid.Validate(channelID) != nil {
		return 0, ErrUnavailable
	}
	roomName := "voice:" + channelID
	listToken, err := client.token(auth.VideoGrant{RoomList: true})
	if err != nil {
		return 0, ErrUnavailable
	}
	rooms, err := client.service(listToken).ListRooms(ctx, &livekit.ListRoomsRequest{Names: []string{roomName}})
	if err != nil || rooms == nil || len(rooms.GetRooms()) > 1 {
		return 0, ErrUnavailable
	}
	if len(rooms.GetRooms()) == 0 {
		return 0, nil
	}
	if rooms.GetRooms()[0] == nil || rooms.GetRooms()[0].GetName() != roomName {
		return 0, ErrUnavailable
	}
	participantToken, err := client.token(auth.VideoGrant{RoomAdmin: true, Room: roomName})
	if err != nil {
		return 0, ErrUnavailable
	}
	participants, err := client.service(participantToken).ListParticipants(ctx, &livekit.ListParticipantsRequest{Room: roomName})
	if err != nil || participants == nil {
		return 0, ErrUnavailable
	}
	return len(participants.GetParticipants()), nil
}
