package social

import (
	"context"
	"errors"
	"strings"
)

type RelationshipRequest struct {
	PlayerID       string `json:"player_id"`
	TargetPlayerID string `json:"target_player_id"`
}

type ListRequest struct {
	PlayerID string
	Limit    int
}

type RelationshipState struct {
	PlayerID       string `json:"player_id"`
	TargetPlayerID string `json:"target_player_id"`
	Following      bool   `json:"following"`
	FollowedBy     bool   `json:"followed_by"`
	Blocked        bool   `json:"blocked"`
	BlockedBy      bool   `json:"blocked_by"`
	UpdatedAt      int64  `json:"updated_at"`
}

type Service interface {
	Follow(ctx context.Context, request RelationshipRequest) (RelationshipState, error)
	Unfollow(ctx context.Context, request RelationshipRequest) (RelationshipState, error)
	Block(ctx context.Context, request RelationshipRequest) (RelationshipState, error)
	Unblock(ctx context.Context, request RelationshipRequest) (RelationshipState, error)
	State(ctx context.Context, request RelationshipRequest) (RelationshipState, error)
	Following(ctx context.Context, request ListRequest) ([]RelationshipState, error)
	Blocked(ctx context.Context, playerID string, targetPlayerID string) bool
}

type relationEntry struct {
	Following bool
	Blocked   bool
	UpdatedAt int64
}

const (
	defaultListLimit = 50
	maxListLimit     = 100
)

func normalizeRequest(request RelationshipRequest) (RelationshipRequest, error) {
	request.PlayerID = strings.TrimSpace(request.PlayerID)
	request.TargetPlayerID = strings.TrimSpace(request.TargetPlayerID)
	if request.PlayerID == "" || request.TargetPlayerID == "" {
		return request, errors.New("player_required")
	}
	if request.PlayerID == request.TargetPlayerID {
		return request, errors.New("self_relationship_forbidden")
	}
	return request, nil
}

func normalizeListRequest(request ListRequest) (ListRequest, error) {
	request.PlayerID = strings.TrimSpace(request.PlayerID)
	if request.PlayerID == "" {
		return request, errors.New("player_required")
	}
	request.Limit = normalizeLimit(request.Limit)
	return request, nil
}

func normalizeLimit(limit int) int {
	if limit <= 0 {
		return defaultListLimit
	}
	if limit > maxListLimit {
		return maxListLimit
	}
	return limit
}

func relationshipKey(playerID string, targetPlayerID string) string {
	return playerID + "\x00" + targetPlayerID
}
