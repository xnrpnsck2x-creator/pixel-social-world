package presence

import (
	"context"
	"testing"
	"time"

	miniredis "github.com/alicebob/miniredis/v2"
	goredis "github.com/redis/go-redis/v9"
)

func TestRedisServiceHeartbeatAndTTL(t *testing.T) {
	redisServer := miniredis.RunT(t)
	client := goredis.NewClient(&goredis.Options{Addr: redisServer.Addr()})
	service := NewRedisService(client, time.Second)
	ctx := context.Background()

	if _, err := service.Heartbeat(ctx, HeartbeatRequest{
		PlayerID:    "player_1",
		RoomID:      "town",
		DisplayName: "One",
	}); err != nil {
		t.Fatalf("Heartbeat returned error: %v", err)
	}
	members, err := service.RoomMembers(ctx, "town")
	if err != nil {
		t.Fatalf("RoomMembers returned error: %v", err)
	}
	if len(members) != 1 || members[0].PlayerID != "player_1" {
		t.Fatalf("expected redis member before ttl, got %#v", members)
	}

	redisServer.FastForward(2 * time.Second)
	members, err = service.RoomMembers(ctx, "town")
	if err != nil {
		t.Fatalf("RoomMembers after ttl returned error: %v", err)
	}
	if len(members) != 0 {
		t.Fatalf("expected ttl to remove redis member, got %#v", members)
	}
}
