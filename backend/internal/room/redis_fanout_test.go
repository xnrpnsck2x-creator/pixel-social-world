package room

import (
	"testing"
	"time"

	miniredis "github.com/alicebob/miniredis/v2"
	goredis "github.com/redis/go-redis/v9"
)

func TestRedisFanoutBroadcastsAcrossHubs(t *testing.T) {
	redisServer := miniredis.RunT(t)
	client := goredis.NewClient(&goredis.Options{Addr: redisServer.Addr()})
	hubA := NewHub(WithFanout(NewRedisFanout(client)))
	defer hubA.Close()
	hubB := NewHub(WithFanout(NewRedisFanout(client)))
	defer hubB.Close()
	serverA := newHubTestServer(t, hubA)
	defer serverA.Close()
	serverB := newHubTestServer(t, hubB)
	defer serverB.Close()

	roomA1 := dialTestSocket(t, serverA.URL)
	defer roomA1.Close()
	roomA2 := dialTestSocket(t, serverB.URL)
	defer roomA2.Close()

	time.Sleep(50 * time.Millisecond)
	writeEnvelope(t, roomA1, joinEnvelope("player_a1", "room_a"))
	writeEnvelope(t, roomA2, joinEnvelope("player_a2", "room_a"))
	writeEnvelope(t, roomA1, Envelope{
		SchemaVersion: 1,
		Type:          "player.move",
		Payload:       map[string]interface{}{"position": map[string]interface{}{"x": 22, "y": 12}},
	})

	move := readUntilType(t, roomA2, "player.move")
	payload := move.Payload.(map[string]interface{})
	if payload["player_id"] != "player_a1" || payload["room_id"] != "room_a" {
		t.Fatalf("unexpected redis fanout payload: %#v", payload)
	}
}
