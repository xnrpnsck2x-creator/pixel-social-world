package gateway

import (
	"context"
	"strings"

	"pixel-social-world/backend/internal/minigame"
)

type roomAuthorizer struct {
	minigameService minigame.Service
}

func NewRoomAuthorizer(service minigame.Service) roomAuthorizer {
	return roomAuthorizer{minigameService: service}
}

func (a roomAuthorizer) CanJoinRoom(ctx context.Context, playerID string, roomID string) bool {
	if playerID == "" || roomID == "" {
		return false
	}
	if roomID == "world_town_square" || !strings.Contains(roomID, ":") {
		return true
	}
	if strings.HasPrefix(roomID, "home:") {
		return strings.TrimPrefix(roomID, "home:") != ""
	}
	if strings.HasPrefix(roomID, "minigame:") {
		return a.canJoinMinigame(ctx, playerID, roomID)
	}
	return false
}

func (a roomAuthorizer) canJoinMinigame(ctx context.Context, playerID string, roomID string) bool {
	parts := strings.Split(roomID, ":")
	if len(parts) != 3 || a.minigameService == nil {
		return false
	}
	session, ok := a.minigameService.GetSession(ctx, parts[2])
	if !ok || session.GameID != parts[1] {
		return false
	}
	for _, memberID := range session.Players {
		if memberID == playerID {
			return true
		}
	}
	return false
}
