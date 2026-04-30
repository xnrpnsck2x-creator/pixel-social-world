package presence

import (
	"context"
	"testing"
	"time"
)

func TestMemoryServiceExpiresMembers(t *testing.T) {
	service := NewMemoryService(10 * time.Millisecond)
	ctx := context.Background()
	if _, err := service.Heartbeat(ctx, HeartbeatRequest{
		PlayerID: "player_1",
		RoomID:   "town",
	}); err != nil {
		t.Fatalf("Heartbeat returned error: %v", err)
	}
	members, err := service.RoomMembers(ctx, "town")
	if err != nil || len(members) != 1 {
		t.Fatalf("expected one member before ttl, got %#v err=%v", members, err)
	}
	time.Sleep(20 * time.Millisecond)
	members, err = service.RoomMembers(ctx, "town")
	if err != nil {
		t.Fatalf("RoomMembers returned error: %v", err)
	}
	if len(members) != 0 {
		t.Fatalf("expected member to expire, got %#v", members)
	}
}
