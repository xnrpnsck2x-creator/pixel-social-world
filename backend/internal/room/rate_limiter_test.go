package room

import (
	"context"
	"testing"
	"time"

	miniredis "github.com/alicebob/miniredis/v2"
	goredis "github.com/redis/go-redis/v9"
)

func TestRedisRateLimiterSharesLimitAcrossInstances(t *testing.T) {
	redisServer := miniredis.RunT(t)
	client := goredis.NewClient(&goredis.Options{Addr: redisServer.Addr()})
	limiterA := NewRedisRateLimiter(client)
	limiterB := NewRedisRateLimiter(client)
	ctx := context.Background()
	key := rateKey("player_a", "player.move")

	if !limiterA.Allow(ctx, key, time.Second) {
		t.Fatal("first limiter call should pass")
	}
	if limiterB.Allow(ctx, key, time.Second) {
		t.Fatal("second limiter instance should share the same redis limit")
	}
	redisServer.FastForward(2 * time.Second)
	if !limiterB.Allow(ctx, key, time.Second) {
		t.Fatal("limiter should pass after ttl expires")
	}
}

func TestHubSnapshotIncludesRealtimeMetrics(t *testing.T) {
	hub := NewHub(WithRateLimits(time.Hour, time.Hour))
	server := newHubTestServer(t, hub)
	defer server.Close()

	roomA1 := dialTestSocket(t, server.URL)
	defer roomA1.Close()
	roomA2 := dialTestSocket(t, server.URL)
	defer roomA2.Close()

	writeEnvelope(t, roomA1, joinEnvelope("player_a1", "room_a"))
	writeEnvelope(t, roomA2, joinEnvelope("player_a2", "room_a"))
	waitForRoomCounts(t, hub, map[string]int{"room_a": 2})
	move := Envelope{
		SchemaVersion: 1,
		Type:          "player.move",
		Payload:       map[string]interface{}{"position": map[string]interface{}{"x": 1, "y": 1}},
	}
	writeEnvelope(t, roomA1, move)
	writeEnvelope(t, roomA1, move)
	_ = readUntilType(t, roomA2, "player.move")

	realtime := waitForRealtimeMetric(t, hub, "local_delivered")
	if realtime["move_rate_limited"] == 0 || realtime["local_delivered"] == 0 {
		t.Fatalf("expected realtime metrics to increment, got %#v", realtime)
	}
}

func waitForRealtimeMetric(t *testing.T, hub *Hub, key string) map[string]int64 {
	t.Helper()
	deadline := time.Now().Add(time.Second)
	var realtime map[string]int64
	for time.Now().Before(deadline) {
		realtime = hub.Snapshot()["realtime"].(map[string]int64)
		if realtime[key] > 0 && realtime["move_rate_limited"] > 0 {
			return realtime
		}
		time.Sleep(10 * time.Millisecond)
	}
	return realtime
}
