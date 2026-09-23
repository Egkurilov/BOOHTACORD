package listmembers

import (
	"context"
	"errors"
	"fmt"

	"github.com/google/uuid"
)

const defaultLimit = 50
const maxLimit = 100

var (
	ErrInvalidInput   = errors.New("invalid member list input")
	ErrMemberNotFound = errors.New("member not found")
)

type Input struct {
	Cursor string
	Limit  int
}
type Member struct {
	ID, Login, DisplayName, Role, AvatarURL string
	HasAvatar                               bool
}
type Result struct {
	Members    []Member
	NextCursor string
}
type Store interface {
	List(context.Context, string, int) ([]Member, error)
	Find(context.Context, string) (Member, error)
}
type Service struct{ store Store }

func New(store Store) Service { return Service{store: store} }

func (service Service) List(ctx context.Context, input Input) (Result, error) {
	if input.Limit < 0 || input.Limit > maxLimit || (input.Cursor != "" && !validUUID(input.Cursor)) {
		return Result{}, ErrInvalidInput
	}
	limit := input.Limit
	if limit == 0 {
		limit = defaultLimit
	}
	members, err := service.store.List(ctx, input.Cursor, limit+1)
	if err != nil {
		return Result{}, fmt.Errorf("list guild members: %w", err)
	}
	result := Result{Members: append([]Member{}, members...)}
	if len(members) > limit {
		result.Members = members[:limit]
		result.NextCursor = result.Members[len(result.Members)-1].ID
	}
	for i := range result.Members {
		if result.Members[i].HasAvatar {
			result.Members[i].AvatarURL = "/api/v1/members/" + result.Members[i].ID + "/avatar"
		}
	}
	return result, nil
}

func (service Service) Get(ctx context.Context, memberID string) (Member, error) {
	if !validUUID(memberID) {
		return Member{}, ErrInvalidInput
	}
	member, err := service.store.Find(ctx, memberID)
	if errors.Is(err, ErrMemberNotFound) {
		return Member{}, ErrMemberNotFound
	}
	if err != nil {
		return Member{}, fmt.Errorf("get guild member: %w", err)
	}
	if member.HasAvatar {
		member.AvatarURL = "/api/v1/members/" + member.ID + "/avatar"
	}
	return member, nil
}

func validUUID(value string) bool { _, err := uuid.Parse(value); return err == nil }
