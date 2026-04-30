package gateway

import (
	"context"
	"testing"

	"pixel-social-world/backend/internal/minigame"
)

func TestRoomAuthorizerRules(t *testing.T) {
	service := minigame.NewMemoryService()
	ctx := context.Background()
	session, err := service.CreateSession(ctx, minigame.CreateSessionRequest{
		GameID:       "fishing",
		RoomID:       "world_town_square",
		HostPlayerID: "player_a",
		MaxPlayers:   2,
	})
	if err != nil {
		t.Fatalf("CreateSession returned error: %v", err)
	}
	authorizer := NewRoomAuthorizer(service)

	if !authorizer.CanJoinRoom(ctx, "player_a", "home:player_a") {
		t.Fatal("owner should be able to join own home")
	}
	if !authorizer.CanJoinRoom(ctx, "player_b", "home:player_a") {
		t.Fatal("authenticated visitors should be able to join public MVP homes")
	}
	if !authorizer.CanJoinRoom(ctx, "player_a", "minigame:fishing:"+session.ID) {
		t.Fatal("session member should be able to join minigame room")
	}
	if authorizer.CanJoinRoom(ctx, "player_b", "minigame:fishing:"+session.ID) {
		t.Fatal("non-member should not be able to join minigame room")
	}
}
