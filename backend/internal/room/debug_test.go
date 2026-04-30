package room

import (
	"testing"
	"time"
)

func TestDebugSnapshotIncludesRoomTypeAndActivity(t *testing.T) {
	now := time.Unix(1777560000, 0)
	hub := NewHub(WithClock(func() time.Time { return now }))
	defer hub.Close()

	hub.mu.Lock()
	hub.clients[nil] = &clientState{
		roomID:       defaultRoomID,
		playerID:     "player_main",
		lastActiveAt: now.Unix(),
	}
	hub.lastMoves["home:owner"] = map[string]map[string]interface{}{
		"visitor": {"last_active_at": now.Add(-5 * time.Second).Unix()},
	}
	hub.mu.Unlock()

	snapshot := hub.DebugSnapshot()
	rooms := snapshot["rooms"].(map[string]map[string]interface{})
	mainRoom := rooms[defaultRoomID]
	if mainRoom["room_type"] != "main_city" || mainRoom["last_active_at"] != now.Unix() {
		t.Fatalf("main room debug metadata missing: %#v", mainRoom)
	}
	homeRoom := rooms["home:owner"]
	if homeRoom["room_type"] != "housing" || homeRoom["snapshot_players"] != 1 {
		t.Fatalf("housing room debug metadata missing: %#v", homeRoom)
	}
}
